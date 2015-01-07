# Dropzone Action Info
# Name: S3 and Bitly
# Description: Uploads file(s) to Amazon S3 and generates short link.
# Handles: Files
# Creator: Andrew Corcoran
# URL: http://corc.im
# OptionsNIB: AmazonS3Login
# Events: Dragged, TestConnection
# SkipConfig: No
# RunsSandboxed: Yes
# Version: 1.0
# MinDropzoneVersion: 3.0
# RubyPath: /System/Library/Frameworks/Ruby.framework/Versions/2.0/usr/bin/ruby

####################

$BITLY_USERNAME = "your-bitly-username"
$BITLY_API_KEY = "your-bitly-apikey"

####################

require 's3'
require 'open-uri'

def dragged
  $dz.begin("Connecting to Amazon S3...")
  $dz.determinate(false)
  determinate = false
  
  s3 = S3.new
  s3.configure_client
  
  urls = []
  prepend_url = ""
  
  if ENV['root_url']
    slash = (ENV['root_url'][-1,1] == "/" ? "" : "/")
    prepend_url = ENV['root_url'] + slash
  end
  
  num_files = $items.length
  has_output_progress = false
  
  $items.each do |file_path|
    filestat = File.stat(file_path)
    $dz.error("Uploading folders not supported", "The Amazon S3 action does not currently support uploading of folders. This feature is planned for a future version.") if filestat.directory?
  end

  $items.each_with_index do |file_path, n|
    basename = File.basename(file_path)
    $dz.begin("Uploading #{basename}...")

    overall_progress = (100 / num_files) * n
    
    uploaded_path = s3.upload_file(file_path, s3.get_bucket) do |file_percent, upload|
      file_progress = (file_percent / $items.length).to_i
      
      overall_plus_file_progress = overall_progress + file_progress

      has_output_progress = true if overall_plus_file_progress < 100
      if has_output_progress
        if not determinate
          $dz.determinate(true)
          determinate = true
        end
        $dz.percent(overall_plus_file_progress) 
      end
      
      if overall_plus_file_progress >= 100 and has_output_progress
        if determinate
          $dz.determinate(false)
          determinate = false
        end
      end
    end
    
    urls << prepend_url + uploaded_path
  end

  finish_message = (ENV['root_url'] ? "URL is now on clipboard" : "Upload Complete") 
  
  if urls.length == 1
    $dz.finish(finish_message)
    $dz.url(minify_url(urls[0]))
  else
    merged_urls = ""
    urls.each do |url|
      merged_urls << URI::encode(minify_url(url)) + "\n"
    end
    $dz.finish(finish_message.sub!(/URL is/, "URLs are"))
    $dz.text(merged_urls.strip)
  end
end
  
def minify_url(long_url)
  if long_url =~ /http/
      username = $BITLY_USERNAME
      apikey = $BITLY_API_KEY
      url = CGI::escape(long_url)
      
      if (username == "your-bitly-username" or apikey == "your-bitly-apikey")
          $dz.error("Bit.ly login details not set", "You need to edit the FTP Upload+Bit.ly.dropzone script and set the $BITLY_USERNAME and $BITLY_API_KEY variables correctly.")
      end
      
      version = "2.0.1"
      bitly_url = "http://api.bit.ly/shorten?version=#{version}&format=xml&longUrl=#{url}&login=#{username}&apiKey=#{apikey}"
      
      $dz.begin("Shortening URL...")
          $dz.determinate(false)
          
          # parse result and return shortened url
          buffer = open(bitly_url, "UserAgent" => "Ruby-ExpandLink").read
          
          doc = REXML::Document.new(buffer)
          doc.elements.each("bitly/errorMessage") do |a|
              if a.text == "INVALID_LOGIN"
                  $dz.finish("Invalid user or API key")
                  $dz.url(false)
                  else
                  doc.elements.each("bitly/results/nodeKeyVal/shortUrl") do |b|
                      if b.text.empty?
                          return false
                          else
                          return b.text
                      end
                  end
              end
          end
          else
          $dz.error("URL From FTP Upload Invalid", "The URL generated from the FTP upload could not be minified as it does not start with http://\n\n\
                    Check the Root URL field in the destination settings starts with http://")
                    $dz.url(false)
  end
end

def test_connection
  s3 = S3.new
  s3.configure_client

  begin
    timeout(20) {
      bucket = s3.get_bucket
      s3.check_bucket_access(bucket, "/")
    }
  rescue Timeout::Error
    $dz.error("Connection Failed", "Connection timed out.")
  end

  $dz.alert("Connection Successful", "Amazon S3 connection succeeded.")
end
