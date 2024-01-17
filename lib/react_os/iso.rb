module ReactOS
  require 'xorriso'
  class ISO < Xorriso
    @inject_files = [
      {
        source: 'unattend.inf',
        target: '/reactos/unattend.inf'
      }
    ]
  end
end
