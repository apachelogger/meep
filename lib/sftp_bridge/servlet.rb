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

require 'net/sftp'
require 'webrick'

require_relative 'file_io_compat'

# Bridging depot.kde.org to HTTP.
class SFTPBridgeServlet < WEBrick::HTTPServlet::AbstractServlet
  def initialize(*args)
    super
    @sftp = Net::SFTP.start('depot.kde.org', 'ftpubuntu')
  end

  def do_GET(request, response)
    remote_path = "/home/ftpubuntu/#{request.path}"
    if @sftp.file.directory?(remote_path)
      get_dir(remote_path, request, response)
    else
      get_file(remote_path, request, response)
    end
  rescue Net::SFTP::StatusException => e
    exception_to_response(e, response)
  end

  private

  def get_dir(path, request, response)
    @sftp.dir.glob(path, '*') do |entry|
      response.body << format("<a href='%s'></a>\n",
                              request.request_uri + entry.name)
    end
  end

  def get_file(path, _request, response)
    file = @sftp.file.open(path)
    response['content-type'] = 'application/octet-stream'
    response.body = file
  end

  def exception_to_response(exception, response)
    response.status = case exception.code
                      when Net::SFTP::Constants::StatusCodes::FX_NO_SUCH_FILE
                        404
                      else
                        500
                      end
    response.body = exception.message
  end
end
