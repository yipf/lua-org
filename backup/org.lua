package.path="/home/yipf/lua-org/?.lua;"..package.path

require "core"

local cls,path,tmplt_dir=...

print(cls,path,tmplt_dir)

cls=cls or "html"
--~ tmplt_dir=tmplt_dir or "/home/yipf1/lua-noweb/templates/"

process_file(cls,path,tmplt_dir)