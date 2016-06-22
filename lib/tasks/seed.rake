namespace :db do
  namespace :seed do
    # Create random data (actually this is an alias for `rake db:seed`
    task :random do
      Rake::Task['db:seed'].invoke
    end

    # Create data from CSV files under db/data
    task sample: :environment do
      require 'csv'

      ignore = ENV['ignore'].blank? ? [] : ENV['ignore'].split(',')

      Dir.glob(File.join(Rails.root, 'db', 'data', '*.csv')).sort.each do |file|

        if ignore.include?(file.gsub(/^.*\//, ''))
          puts "Ignoring #{file}..."
        else
          puts "Parsing #{file}..."
          name = file.gsub(/.*[0-9]_([^\.]+)\.csv/, '\1')
          model = name.singularize.camelize.constantize
          header = []
          model.delete_all
          #ActiveRecord::Base.connection.execute("ALTER TABLE #{name} AUTO_INCREMENT = 1")
          CSV.foreach(file, quote_char: '`') do |row|
            if header.blank?
              header = row
            else
              data = model.new
              row.each_with_index do |value, index|
                value = JSON.parse(value) unless (value =~ /^[\[\{]/).nil?
                method = header[index]
                if data.respond_to?(method + '=')
                  data.send(method + '=', value)
                elsif data.respond_to?(method)
                  data.send(method, value)
                else
                  raise "#{data} does not respond to #{method}!"
                end
              end
              data.save!
            end
          end
        end

      end
    end

  end
end
