# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require 'webrick'

require_relative 'sftp_bridge/servlet'

class SFTPBridge
  attr_reader :host
  attr_reader :port

  def initialize
    # @host = 'localhost'
    @port = ENV.fetch('PORT', 3000)
    @server_thread = nil
  end

  def run
    start
    yield self
    stop
  end

  private

  def wake(mutex, thread)
    proc do
      mutex.synchronize { thread.wakeup }
    end
  end

  def start
    mutex = Mutex.new
    mutex.synchronize do
      @server_thread = start_thread(wake(mutex, Thread.current))
      mutex.sleep
    end
  end

  def start_thread(callback)
    Thread.new do
      Thread.abort_on_exception = true
      server = WEBrick::HTTPServer.new(Port: @port,
                                       StartCallback: callback)
      @port = server.listeners[0].addr[1]
      server.mount('/', SFTPBridgeServlet)
      # trap 'INT' do server.shutdown end
      server.start
    end
  end

  def start_server
          server = WEBrick::HTTPServer.new(Port: @port)
          @port = server.listeners[0].addr[1]
          server.mount('/', SFTPBridgeServlet)
          trap 'INT' do server.shutdown end
              trap 'TERM' do server.shutdown end
          server.start
        end

  def stop
    @server_thread.kill
    @server_thread = nil
    @port = 0
  end
end
