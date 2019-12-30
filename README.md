# Process::Metrics

Extract performance and memory metrics from running processes.

[![Build Status](https://travis-ci.com/socketry/process-metrics.svg)](https://travis-ci.com/socketry/process-metrics)

## Installation

To add it to your current project:

	bundle add process-metrics

## Usage

```ruby
#!/usr/bin/env ruby

require 'process/metrics'

metrics = Process::Metrics.capture(pid: Process.pid)

pp metrics
# [{:pid=>274305,
#   :pgid=>274305,
#   :pcpu=>0.0,
#   :time=>0,
#   :vsz=>78808,
#   :rss=>14324,
#   :etime=>0,
#   :command=>"ruby /tmp/028e1ca9-409b-478d-81b0-062f4f947962",
#   :memory=>
#    {:total=>78812,
#     :rss=>14508,
#     :pss=>9187,
#     :shared_clean=>5652,
#     :shared_dirty=>0,
#     :private_clean=>56,
#     :private_dirty=>8800,
#     :referenced=>14508,
#     :anonymous=>8800,
#     :swap=>0,
#     :swap_pss=>0,
#     :maps=>150}}]
```

Memory is measured in kilobytes and time is measured in seconds.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

Released under the MIT license.

Copyright, 2019, by [Samuel G. D. Williams](http://www.codeotaku.com).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
