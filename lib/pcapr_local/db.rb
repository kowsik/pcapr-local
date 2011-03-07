# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'couchrest'

module PcaprLocal
class DB
    def self.get_db config
        database = config.fetch "database"
        base = config.fetch "uri"

        couch_url = File.join(base, database)
        db = CouchRest.database! couch_url
        patch_db db

        begin
            design = db.get("_design/pcaps") 
        rescue RestClient::ResourceNotFound
            design = CouchRest::Design.new
            design.name = "pcaps"
            design.database = db
            db.save_doc design
        end

        db.update_doc "_design/pcaps" do |design|
            design['views'] = self.views
            design
        end

        db
    end

    # Patch couch to include create and update times for each document.
    def self.patch_db pcapr_local
        def pcapr_local.update_doc id, &block
            super(id) do |doc|
                doc = block.call doc
                doc['updated_at'] = Time.now
                doc
            end
        end

        def pcapr_local.save_doc *args
            doc = args[0]
            now = Time.now
            doc["created_at"] ||= now
            doc["updated_at"] ||= now
            super
        end

        # Performs a query and yields each row to the the supplied block.
        # Uses paging to split the query into page_size chunks.
        def pcapr_local.each_in_view view, query=nil, page_size=50 #block
            query ||= {}
            limit = page_size + 1
            query[:limit] = limit

            begin
                res = self.view(view, query)
                rows = res['rows']
                next_doc = rows.size == limit ? rows.pop : nil
                if next_doc
                    query[:startkey] = next_doc['key']
                    query[:startkey_docid] = next_doc['id']
                end

                rows.each do |row|
                    yield row
                end
            end while next_doc
        end

        nil
    end

    def self.views
            {
            "by_created_at" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap') {
                        emit(Date.parse(doc.created_at), null);
                    }
                })
            },
            "by_inode" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap') {
                        emit(doc.stat.inode, null);
                    }
                })
            },
            "by_filename" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap') {
                        emit(doc.filename, null);
                    }
                })
            },
            "by_directory" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap') {
                        var paths = doc.filename.split('/');
                        paths.unshift(paths.length-1);
                        paths.pop();
                        paths.push(Date.parse(doc.created_at));
                        emit(paths,1);
                    }
                }),
                "reduce" => '_sum'
            },
            "by_path" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap') {
                        var paths = doc.filename.split('/');
                        paths.pop();
                        emit(paths,1);
                    }
                }),
                "reduce" => '_sum'
            },
            "by_service" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap' && doc.index) {
                        var services = doc.index.services;
                        for (var i=0; i<services.length; ++i) {
                            emit([ services[i], Date.parse(doc.created_at) ], 1);
                        }
                    }
                }),
                "reduce" => '_sum'
            },
            "indexed" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap') {
                        if (doc.status === 'indexed') {
                            emit(doc.filename, null);
                        }
                    }
                })
            },
            "queued" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap') {
                        if (doc.status === 'queued' || doc.status === 'indexing') {
                            emit(doc.filename, null);
                        }
                    }
                })
            },
            "by_status" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap') {
                        emit([ doc.status, Date.parse(doc.created_at) ], 1);
                    }
                }),
                "reduce" => '_sum'
            },
            "by_keyword" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap') {
                        var keywords = {};
                        var paths = doc.filename.split('/');
                        for (var p in paths) {
                            var tokens = paths[p].toLowerCase().split(/[ -_\.\\\/\(\)]/);
                            for (var t in tokens) {
                                if (tokens[t].length > 2) {
                                    keywords[tokens[t]] = true;
                                }
                            }
                        }
                                                
                        for (var k in keywords) {
                            emit([ k, Date.parse(doc.created_at) ], 1);
                        }
                    }
                }),
                "reduce" => '_sum'
            },
            "statistics" => {
                "map" => %q(function(doc) {
                    if (doc.type === 'pcap') {
                        emit('pcaps', 1);
                        emit('bytes', doc.stat.size);
                        if (doc.index) {
                            emit('packets', doc.index.about.packets);
                            emit('flows', doc.index.about.flows);
                            emit('services', doc.index.about.services);
                        }
                    }
                }),
                "reduce" => '_sum'
            }
            }
    end
end
end
