#! /usr/bin/env ruby
# coding: utf-8

$:.unshift File.expand_path(File.dirname(__FILE__)) + "/lib"

require 'post_index'

PostIndexRunner.new ARGV
