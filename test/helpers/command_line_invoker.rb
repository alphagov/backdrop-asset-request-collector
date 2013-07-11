module CommandLineInvoker
  def invoke(cmd, stdin, args = {})
    stdin = [*stdin].join("\n")
    cmd = File.dirname(__FILE__) + "/../../bin/" + cmd
    args.each do |argname, argvalue|
      cmd << " --#{argname} #{argvalue}"
    end
    stdout, stderr, status = Open3.capture3(cmd, stdin_data: stdin)
    raise stderr unless status.exitstatus == 0
    stdout.split("\n")
  end
end