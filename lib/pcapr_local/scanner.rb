# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'find'
require 'set'
require 'fileutils'
require 'tempfile'
require 'digest/md5'

module PcaprLocal
class Scanner

    # Creates scanner instance and starts it.
    def self.start config
        scanner = Scanner.new config
        scanner.start
        scanner
    end

    # Runs scanner loop in separate thread.
    def start
        Logger.info "Starting scanner thread"
        Thread.new do
            loop do 
                begin
                    scan
                    @db.compact!
                rescue Exception => e
                    Logger.error "Exception during scanning: #{e.message}\n" + e.backtrace.join("\n")
                end
                sleep @scan_interval
            end
        end
    end

    def initialize config
        @db = config.fetch('db')
        @xtractr = config.fetch('xtractr')
        @pcap_dir  = File.expand_path(config.fetch('pcap_dir'))
        @index_dir = File.expand_path(config.fetch('index_dir'))
        @queue_delay = config.fetch('queue_delay')
        @scan_interval = config.fetch('interval')
    end

    # Removes doc from database and corresponding index file.
    # Does _not_ remove original pcap.
    def remove_doc doc
        @db.delete_doc(doc)
        if filename = doc['filename']
            FileUtils.rm_f pcap_path(filename)
            remove_index_for(filename)
        end
    end

    def scan
        # Get list of all pcaps
        pcaps = self.find_pcaps
        # Cleanup db and queue new pcaps
        reconcile_with_db pcaps
        # Index queued pcaps.
        self.index
    end

    RE_PCAP = /\.p?cap\Z/

    # Returns a set of pcap files (relative paths)
    def find_pcaps
        if not File.directory?(@pcap_dir) or not File.readable?(@pcap_dir)
            return Set.new
        end

        pcaps = Set.new
        pcap_prefix_size = @pcap_dir.size + 1 # /
        Find.find @pcap_dir do |path|
            # Don't recurse into ".pcapr_local" or other "." dirs
            if File.basename(path) =~ /^\./
                Find.prune
            end

            # Should be a file ending in .cap or .pcap
            next unless path =~ RE_PCAP and File.file?(path)

            rel_path = path[pcap_prefix_size..-1]
            pcaps << rel_path
        end
        pcaps
    end

    def requeue_pcap rel_path
        res = @db.view("pcaps/by_filename", :key => rel_path)
        return nil if res['rows'].empty?

        id = res['rows'][0]["id"]
        @db.update_doc id do |doc|
            doc['status'] = 'queued'
            doc.delete 'index'
            doc
        end
    end
 
    # Adds pcap to db with status set to "queued". Returns nil w/out 
    # updating db if the pcap was modified within the last queue_delay
    # seconds (because pcap may not be completely copied to pcap_dir).
    def add_pcap relative_path
        now = Time.new
        stat = File.stat(File.join(@pcap_dir, relative_path))
        if now - stat.mtime < @queue_delay
            return
        end

        # Pick determistic doc id based on path and pcap size.
        # (for testing convenience).
        id = Digest::MD5.new
        id << "#{relative_path}:#{stat.size}"

        doc = CouchRest::Document.new({
            :_id => id.to_s,
            :type => 'pcap',
            :filename => relative_path,
            :status => 'queued',
            :stat => {
                :inode => stat.ino,
                :size => stat.size,
                :ctime => stat.ctime,
            },
            :created_at => now,
            :updated_at => now,
        })
        @db.save_doc doc

        doc
    end

    # Indexes all documents in queue. Returns count of documents indexed.
    def index
        count = 0
        @db.each_in_view("pcaps/queued", :include_docs => true) do |row|
            index_pcap row['doc']
            count += 1
        end
        count
    end

    # Creates xtractr index for pcap. Updates status from "queued" to "indexing" to "indexed".
    # Any exception will result in a status of "failed" with the exception's message copied
    # to the document's message attribute.
    def index_pcap pcap
        relative_path = pcap["filename"]
        pcap_path = File.join(File.expand_path(@pcap_dir), relative_path)
        index_dir = File.join(File.expand_path(@index_dir), relative_path)

        # Index
        Logger.info "Indexing #{relative_path}"
        begin
            @db.update_doc pcap["_id"] do |doc|
                doc["status"] = "indexing"
                doc
            end

            index_data = @xtractr.index pcap_path, index_dir

            @db.update_doc pcap["_id"] do |doc|
                doc['index'] = index_data
                doc['status'] = 'indexed'
                doc
            end
        rescue 
            Logger.warn "Indexing failure: #{$!.message}"
            @db.update_doc pcap["_id"] do |doc|
                doc['status']  = "failed"
                doc['message'] = $!.message
                doc
            end
        end

        return
    end

    def pcap_path rel_path
        if rel_path.is_a? Hash
            rel_path = rel_path[:filename] or raise "path not found in #{rel_path.inspect}"
        end
        File.expand_path File.join(@pcap_dir, rel_path)
    end

    def index_path rel_path
        if rel_path.is_a? Hash
            rel_path = rel_path.fetch :filename
        end
        File.expand_path File.join(@index_dir, rel_path)
    end

    # Because FileUtils.rm_rf is too dangerous.
    def remove_index_for rel_path
        target = index_path rel_path
        if File.directory? target
            FileUtils.rm_rf Dir.glob("#{target}/*.db")
            FileUtils.rmdir target rescue nil
        end
    end

    # Checks each pcap in the database, purging or requeueing documents as necessary. 
    # Any pcaps in fs_pcaps that are not in the database are added.
    def reconcile_with_db fs_pcaps
        fs_pcaps = fs_pcaps.dup 

        indexed = Set.new
        @db.each_in_view("pcaps/indexed") do |row|
            indexed << row['key']
        end

        @db.each_in_view("pcaps/by_filename") do |row|
            path = row['key']

            # Delete record if from database if pcap is not present on the 
            # file system.
            if not fs_pcaps.include? path
                Logger.warn "Indexer: removing database entry for missing pcap #{path}"
                @db.delete_doc @db.get(row['id'])
                remove_index_for(path)

                next
            end

            # Requeue pcap if xtractr index is missing or is older than the pcap.
            if indexed.include? path
                pcap_index_dir = File.join(@index_dir, path)
                if not Xtractr.index_dir?(pcap_index_dir)
                    Logger.warn "Index is missing, requeueing #{path}"
                    requeue_pcap path
                elsif Xtractr.index_time(pcap_index_dir) < File.mtime(pcap_path(path)).to_f
                    Logger.info "Pcap is newer than index, requeueing #{path}"
                    requeue_pcap path
                end
            end

            fs_pcaps.delete path
        end

        # Remaining pcaps are unknown, add them to database
        fs_pcaps.each do |path|
            Logger.debug "New pcap: #{path}"
            add_pcap path
        end
    end
end
end


