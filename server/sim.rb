#!/usr/bin/ruby
#
# This file is part of etm/proc_sim_reactor.
#
# etm/proc_sim_reactor is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 3 of the License, or (at your
# option) any later version.
#
# etm/proc_sim_reactor is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public License
# for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with etm/proc_sim_reactor (file LICENSE in the main directory); if not,
# see <http://www.gnu.org/licenses/>.

require 'json'
require 'riddl/server'
require 'riddl/protocols/utils'
require 'fileutils'

module Reactor
  R = 0.08206
  Y_AXIS_NORMALIZE = 10.0

  def self::change(vals,state,behavior)
    if state['heat']
      vals['t'] =  vals['t'] + behavior['h']
    else
      vals['t'] =  vals['t'] + behavior['c']
    end
  end

  def self::range_normalize(v,f,t)
    chunk = (t-f)/Reactor::Y_AXIS_NORMALIZE
    if v < f
      -((f-v)/chunk)
    elsif v > t
      Reactor::Y_AXIS_NORMALIZE + ((v-t)/chunk)
    else
      (v-f)/chunk
    end
  end

  def self::normalize(vals,goals)
    {
      'p' => Reactor::range_normalize(vals['p'],goals['p']['f'],goals['p']['t']),
      't' => Reactor::range_normalize(vals['t'],goals['t']['f'],goals['t']['t']),
      'n' => Reactor::range_normalize(vals['n'],goals['n']['f'],goals['n']['t'])
    }
  end

  def self::calculate(vals,goals,conns)
    vals['p'] = (vals['n'] * R * vals['t']) / vals['v']
    ret = Reactor::normalize(vals,goals)
    conns.each do |e|
      e.send JSON::generate(ret)
    end
    true
  rescue
    false
  end
end

class Active < Riddl::SSEImplementation
  def onopen
    @conns = @a[0]
    @conns << self
  end
  def onclose
    @conns.delete(self)
  end
end

server = Riddl::Server.new(File.join(__dir__,'/sim.xml'), :host => 'localhost') do |opts|
  accessible_description true
  cross_site_xhr true

  @riddl_opts[:connections] = []
  @riddl_opts[:interval] ||= 1.0

  parallel do
    Thread.abort_on_exception = true
    loop do
      Reactor::change(@riddl_opts[:values],@riddl_opts[:state],@riddl_opts[:behavior])
      Reactor::calculate(@riddl_opts[:values],@riddl_opts[:goals],@riddl_opts[:connections])
      sleep @riddl_opts[:interval]
    end
  end

  on resource do
    on resource 'data' do
      run Active, @riddl_opts[:connections] if sse
    end
    on resource 'control' do
    end
  end
end.loop!
