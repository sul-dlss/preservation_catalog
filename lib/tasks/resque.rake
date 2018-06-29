require 'resque/tasks'
task 'resque:setup' => :environment

require 'resque/pool/tasks'
task "resque:pool:setup" do
  ActiveRecord::Base.connection.disconnect! # close any sockets or files in pool manager
  Resque::Pool.after_prefork do |_job|
    ActiveRecord::Base.establish_connection # and re-open them in the resque worker parent
  end
end
