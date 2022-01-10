module ReactOS
  require 'xorriso'
  class ISO < Xorriso
    require 'find'
    require 'shellwords'

    @inject_files = [
      {
        source: 'unattend.inf',
        target: '/reactos/unattend.inf'
      }
    ]

  end
end
