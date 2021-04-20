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

module WebValue #{{{
  def self::parse_value(value)
    case value.downcase
      when 'true'
        true
      when 'false'
        false
      when 'nil', 'null'
        nil
      else
        begin
          JSON::parse(value)
        rescue
          (Integer value rescue nil) || (Float value rescue nil) || value.to_s rescue nil || ''
        end
    end
  end
end #}}}

module Reactor
  def self::change(vals) #{{{
    vals['heat'] = false if vals['t'] > 600 # safety first, switch off reactor if temperature is over 600

    # make it interessting
    vals['h'] = rand(50) if vals['heat']
    vals['c'] = -rand(30) if !vals['heat']
    if rand(10) > 7
      vals['heat'] = !vals['heat']
      vals['m'] = (rand(3) + 1).to_f
    end
    vals['heat'] = false if vals['p'] && vals['p'] > 300000  # if pressure to hight cool down

    # change temperature
    if vals['heat']
      vals['t'] =  vals['t'] + vals['h']
    else
      vals['t'] =  vals['t'] + vals['c']
    end
    vals['t'] = 293.15 if vals['t'] < 293.15  # never go below 20 degrees (room temperature)

    # calculate pressure
    vals['p'] = (vals['m'] * vals['r'] * vals['t']) / vals['v']
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

  def self::calculate(vals,goals,display,y_normalize) #{{{
    ret = {}
    display.each do |e|
      ret[e.to_s] = Reactor::range_normalize(vals[e],goals[e]['f'],goals[e]['t'],y_normalize)
      ret[e.to_s + '_orig'] = vals[e]
    end
    (vals.keys - display).each do |k|
      ret[k] = vals[k]
    end
    ret
  rescue
    puts e.message
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
  end #}}}
end

class Active < Riddl::SSEImplementation #{{{
  def onopen
    @conns = @a[0]
    @conns << self
  end
  def onclose
    @conns.delete(self)
  end
end #}}}

class GetAll < Riddl::Implementation
  def response
    Riddl::Parameter::Complex.new('json','application/json',JSON::pretty_generate(@a[0]))
  end
end
class GetVal < Riddl::Implementation
  def response
    if @a[0].has_key? @r[-1]
      Riddl::Parameter::Complex.new('json','application/json',JSON::pretty_generate(@a[0][@r[-1]]))
    else
      @status = 404
    end
  end
end
class PutVal < Riddl::Implementation
  def response
    if @a[0].has_key? @r[-1]
      x = WebValue::parse_value @p[0].value
      a = @a[0][@r[-1]].class
      b = x.class
      if a == b  || (a == TrueClass && b == FalseClass) || (a == FalseClass && b == TrueClass)
        @a[0][@r[-1]] = x
      else
        @status = 400
      end
    else
      @status = 404
    end
    nil
  end
end
class PutRange < Riddl::Implementation
  def response
    if @a[0].has_key? @r[-1]
      @a[0][@r[-1]]['f'] = WebValue::parse_value @p[0].value
      @a[0][@r[-1]]['t'] = WebValue::parse_value @p[1].value
    else
      @status = 404
    end
    nil
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
      Reactor::change(@riddl_opts[:values])
      vals = Reactor::calculate(@riddl_opts[:values],@riddl_opts[:goals],@riddl_opts[:display],@riddl_opts[:y_normalize])
      Reactor::send(vals,@riddl_opts[:labels],@riddl_opts[:display],@riddl_opts[:goals],@riddl_opts[:connections])
      sleep @riddl_opts[:interval]
    end
  end

  on resource do
    on resource 'data' do
      run Active, @riddl_opts[:connections] if sse
    end
    on resource 'goals' do
      run GetAll, @riddl_opts[:goals] if get
      on resource do
        run GetVal, @riddl_opts[:goals] if get
        run PutRange, @riddl_opts[:goals] if put 'range'
      end
    end
    on resource 'values' do
      run GetAll, @riddl_opts[:values] if get
      on resource do
        run GetVal, @riddl_opts[:values] if get
        run PutVal, @riddl_opts[:values] if put 'value'
      end
    end
    on resource 'labels' do
      run GetAll, @riddl_opts[:labels] if get
    end
    on resource 'display' do
      run GetAll, @riddl_opts[:display] if get
    end
  end
end.loop!
