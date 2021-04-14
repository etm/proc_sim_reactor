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
  def self::change(vals,state,behavior) #{{{
    state['h'] = false if vals['t'] > 600 # safety first, switch off reactor if temperature is over 600
    p state
    if state['h']
      vals['t'] =  vals['t'] + behavior['h']
    else
      vals['t'] =  vals['t'] + behavior['c']
    end
    vals['t'] = 293.15 if vals['t'] < 293.15  # never go below 20 degrees (room temperature)
    p vals
  end #}}}

  def self::range_normalize(v,f,t,y_normalize) #{{{
    chunk = (t-f)/y_normalize
    if v < f
      -((f-v)/chunk)
    elsif v > t
      y_normalize + ((v-t)/chunk)
    else
      (v-f)/chunk
    end
  end #}}}

  def self::normalize(vals,goals,state,y_normalize) #{{{
    {
      'p' => Reactor::range_normalize(vals['p'],goals['p']['f'],goals['p']['t'],y_normalize),
      't' => Reactor::range_normalize(vals['t'],goals['t']['f'],goals['t']['t'],y_normalize),
      'm' => Reactor::range_normalize(vals['m'],goals['m']['f'],goals['m']['t'],y_normalize),
      'v' => vals['v'],
      'r' => vals['r'],
      'h' => state['h']
    }
  rescue => e
      puts e
  end #}}}

  def self::calculate(vals,goals,state,y_normalize) #{{{
    vals['p'] = (vals['m'] * vals['r'] * vals['t']) / vals['v']
    Reactor::normalize(vals,goals,state,y_normalize)
  rescue
    {}
  end #}}}

  def self::send(vals,labels,display,goals,conns) #{{{
    ret = {
      'labels' => labels,
      'display' => display,
      'goals' => goals,
      'values' => vals
    }
    conns.each do |e|
      e.send JSON::generate(ret)
    end
  end
end #}}}

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
  @riddl_opts[:y_normalize] ||= 10
  @riddl_opts[:y_normalize] = @riddl_opts[:y_normalize].to_f

  parallel do
    loop do
      Reactor::change(@riddl_opts[:values],@riddl_opts[:state],@riddl_opts[:behavior])
      vals = Reactor::calculate(@riddl_opts[:values],@riddl_opts[:goals],@riddl_opts[:state],@riddl_opts[:y_normalize])
      Reactor::send(vals,@riddl_opts[:labels],@riddl_opts[:display],@riddl_opts[:goals],@riddl_opts[:connections])
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
