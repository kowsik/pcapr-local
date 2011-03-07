# http://www.mudynamics.com
# http://labs.mudynamics.com
# http://www.pcapr.net

require 'rack'
require 'rack/contrib/jsonp'
require 'sinatra'
require 'pcapr_local/db'
require 'pcapr_local/scanner'
require 'pcapr_local/xtractr'
require 'mu/scenario/pcap'

module PcaprLocal
class Server < Sinatra::Base
    set :app_file, __FILE__
    root = File.expand_path(File.dirname(__FILE__))
    set :public, File.join(root, 'www')

    use Rack::JSONP
    mime_type :template, 'application/octet-stream'
    mime_type :par, 'application/octet-stream'

    helpers do
        # View as object by joining keys and values.
        # e.g. {"key" => "foo", "value" => "bar"}
        # becomes 
        # {"foo" => "bar"}
        def as_object result
            obj = {}
            result['rows'].each do |row|
                key = row['key']
                if key.is_a? Array
                    # behave like javascript Array.toString
                    key = key.join ","
                end

                val = row['value']
                if val.is_a? Array
                    # behave like javascript Array.toString
                    key = key.join ","
                end

                obj[key] = val
            end
            obj
        end
    end

    # Main page.
    get '/' do
        redirect '/home/index.html'
    end

    # Count of pcaps by status.
    get '/pcaps/1/status' do
        db = settings.db
        content_type :json
        result = db.view 'pcaps/by_status', :group => true
        return as_object(result).to_json
    end

    # High level statistics.
    get '/pcaps/1/statistics' do
        db = settings.db
        content_type :json

        result = db.view 'pcaps/statistics', :group => true

        as_object(result).to_json
    end

    VIEWS = {
        'date'      => 'pcaps/by_created_at',
        'path'      => 'pcaps/by_path',
        'status'    => 'pcaps/by_status',
        'service'   => 'pcaps/by_service',
        'keyword'   => 'pcaps/by_keyword',
        'filename'  => 'pcaps/by_filename',
        'directory' => 'pcaps/by_directory',
    }

    # List/query pcaps by CouchDB view.
    get '/pcaps/1/list' do
        content_type :json
        db = settings.db
        query = params.dup
        by = query.delete('by') 
        by ||= 'date'
        view = VIEWS[by]
        query.delete 'callback'
        ['startkey', 'endkey', 'key'].each do |key| 
            if val = query[key]
                # JSON parser doesn't work unless value is an array or
                # hash. (I.e. this fails: JSON.parse(1.to_json)
                # So enclosing the value in a top level array.
                parsed = JSON.parse("[#{val}]").pop
                query[key] = parsed
            end
        end

        db.view(view, query).to_json
    end

    # Returns doc for pcap.
    get '/pcaps/1/about/:id' do
        content_type :json
        settings.db.get(params[:id]).to_json
    end

    # Deletes document if it has a failed status.
    get '/pcaps/1/remove/:id' do
        content_type :json
        id = params[:id]
        doc = settings.db.get(params[:id])
        if doc and doc['status'] == 'failed'
            settings.scanner.remove_doc doc
            {'ok' => true}.to_json
        else
            {'error' => true, 'reason' => 'status is not failed'}.to_json
        end
    end

    # Explore pcap on pcapr.
    get '/pcaps/1/pcap/:id' do
        id = params[:id]
        doc = settings.db.get(params[:id])
        if doc and doc['index']
            version = doc['index']['about']['version']
            location = "http://www.pcapr.net/xtractr/explore?version=#{version}&" \
            "url=http://#{request.host_with_port}#{request.path}" 
            redirect location
        else
            return {"error" => true , "message" => "not found"}.to_json
        end
    end

    # Forward requests (GET) to xtractr browser instance.
    get '/pcaps/1/pcap/:id/*' do
        id  = params[:id]
        path = params[:splat][0]
        url = "#{path}?#{request.query_string}"
        doc = settings.db.get(params[:id])
        status, headers, body =  settings.xtractr.get(doc['filename'], url)
        headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
        return status, headers, body
    end

    # Forward requests (POST) to xtractr browser instance.
    post '/pcaps/1/pcap/:id/*' do
        id  = params[:id]
        path = params[:splat][0]
        url = "#{path}?#{request.query_string}"
        doc = settings.db.get(params[:id])
        status, headers, body =  settings.xtractr.post(doc['filename'], url, request.body.read)
        headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
        return status, headers, body
    end

    # Download archive that includes dissected and normalized pcap.
    get '/pcaps/1/export_to_par/:id' do
        content_type :par
        id = params[:id]
        doc = settings.db.get(params[:id])
        raise "not found" unless doc
        path = settings.scanner.pcap_path(doc)
        io = Mu::Scenario::Pcap.export_to_par path
        filename = File.basename(doc['filename']).gsub(/[.][^.]*$/, '.par')
        return 200, {'Content-Disposition' => "filename=#{filename}" }, io
    end

    # Record any exceptions in main logfile.
    after '/pcaps/*' do
        if err=request.env['sinatra.error']
            PcaprLocal::Logger.error "UI got an error: #{err.message}\n#{err.backtrace.join("\n")}"
        end
    end
end
end
