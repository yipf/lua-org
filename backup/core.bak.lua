-- For all object, 'CAPTION' stands for contents for itself, "VALUE" stand for values of its children
-- For every object, 'CAPTION' must be set while 'VALUE' would be empty.

-- functions  for input
local blocks={}

file2tree=function(filepath,stack,doc)
	doc=doc or {TYPE=0}
	stack=stack or {} 
	local base=#stack
	local match=string.match
	local tag,op,content,level
	local push,pop,loadstring,setfenv,len=table.insert,table.remove,loadstring,setfenv,string.len
	local block,level,top={}
	local f=io.open(filepath)
	if f then
		for line in f:lines() do
			tag,op,content=match(line,"^([%*@]+)(%S*)%s*(.-)%s*$")
			level=tag and match(tag,"^%*+()")
			if level then -- it is a toc line
				level=level+base-1
				top=pop(stack)
				while top and top.LEVEL>=level do top=pop(stack) end
				if top then push(stack,top) else top=doc end -- let top be the upper level of current block
				if match(content,"%S") then -- if not empty
					block={TYPE="SEC",LEVEL=level,CAPTION=content}
					blocks[content]=block -- register the block to blocks
					push(top,block)
					push(stack,block)
				end
			elseif tag=="@" then -- command lines
				if op=="INCLUDE" then -- inlcude file
					file2tree(content,stack)
				else
					block=stack[#stack] or doc;
					local f=loadstring(content)
					f= f and setfenv(f,block) or f
					if type(f)=="function" then 
						f() 
					else
						print("unexecutable string:",content)
					end
				end
			else -- push the line directly
				block=stack[#stack] or doc;	push(block,line);
			end
		end
		f:close()
	end
	return doc 
end

local tocs={}

local make_counter=function(sep,s,e)
	local ids={}
	local concat=table.concat
	sep=sep or "."
	s=s or 0
	e=e or 0
	return function(key)
		if type(key)=='number' then
			local id=ids[key] or 0
			id=id+1
			ids[key]=id
			ids[key+1]=0
			return concat(ids,sep,1,key)
		else
			local id=ids[key] or 0
			id=id+1
			ids[key]=id
			return (s>0 and e>=s and concat(ids,sep,s,e)..sep or "")..id 
		end
	end
end

local tree2toc
tree2toc=function(tr,counter,sep,s,e)
	counter=counter or make_counter(sep,s,e)
	local tp=tr.TYPE
	tr.ID=counter(tp=="SEC" and tr.LEVEL or tp)
	local toc=tocs[tp]
	if not toc then toc={} tocs[tp]=toc end
	table.insert(toc,tr)
	for i,v in ipairs(tr) do
		if type(v)=="table" then tree2toc(v,counter) end
	end
	return tocs
end

----- functions for output
local hooks,current
local match,gsub,type=string.match,string.gsub,type

local convert=function(tp,o)
	tp=tp and current[tp]
	if tp then
		if type(tp)=="function" then 
			return tp(o)
		else
			return (gsub(tp,"@(.-)@",o))
		end
	end
end

local str2args=function(str)
	local t={}
	local i=0
	local tostring=tostring
	t[i]=str; t[tostring(i)]=str
	for w in string.gmatch(str.."|","(.-)|") do
		i=i+1
		t[i]=w; t[tostring(i)]=w
	end
	return t
end

local process_element=function(tp,content)
	local op,arg,h
	if tp=="#" then
		op,arg=match(content,"^([^:%s]+):(.-)$")
		h=hooks[op]
		if h then return h(arg) end
		if op then return convert(op,str2args(arg)) end
	else
		return convert(tp,content)
	end
end

local process_string=function(str)
	str=gsub(str,"(%p)%1%s*(.-)s*%1%1",process_element)
	return str
end

local str2list_item=function(str)
	local level,tag,content=match(str,"^%s*()(%d*[%.%-]+)%s+(.-)%s*$")
	return level and {LEVEL=level,TYPE=tonumber(tag) and "OL" or "UL",{TYPE="LI",CAPTION=content}}
end

local process_lists=function(src,dst)
	dst=dst or {}
	local push,pop=table.insert,table.remove
	local stack={}
	local v,li,level,top
	for i=1,#src do
		v=src[i]
		if type(v)=="string" then
			li=str2list_item(v)
			if li then  -- it is a list line
				level=li.LEVEL
				top=pop(stack)
				while top and top.LEVEL>level do top=pop(stack) end
				if top then -- there have previous list items
					if top.LEVEL==level then -- same level list
						push(top,li[1]) -- add to 'top' as an item
						push(stack,top) -- push 'top' back to stack
					else -- father list
						push(top[#top],li) -- add to 'top' as a sublist
						push(stack,top) -- push 'top' back to stack
						push(stack,li) -- push 'li' to top of the stack
					end
				else -- if the stack is empty
					push(dst,li)
					push(stack,li)
				end
			else 
				while stack[1] do pop(stack) end -- empty stack
				v=match(v,"%S") and {TYPE="P",CAPTION=v}
				if v then push(dst,v) end
			end
		else
			while stack[1] do pop(stack) end -- empty stack
			push(dst,v)
		end
	end
	return dst
end

local obj2str
obj2str=function(obj)
	if type(obj)~="table" then return process_string(obj) end
	-- process blocks
	local tp=obj.TYPE
	local t=obj
	if tp=="SEC" then  t=process_lists(obj) end  --if a toc object
	for i,v in ipairs(t) do t[i]=obj2str(v)  end
	obj.VALUE=table.concat(t,"\n")
	obj.CAPTION=obj.CAPTION and process_string(obj.CAPTION)
	return convert(tp=="SEC" and obj.LEVEL or tp,obj)
end

-- function for custom
hooks={
	file=function(filepath)
		local f=io.open(filepath)
		local str
		if f then str=f:read("*a"); f:close() end
		return str
	end,
	lua=function(str)
		local f=loadstring("return "..str)
		return f and f()
	end,
	ref=function(str)
		str=blocks[str]
		return str and convert("ref",str)
	end,
	invisible=function(str)
		return convert(str,"") or ""
	end,
	toc=function(str)
		local args=str2args(str)
		local v,t,all
		local concat,rep=table.concat,string.rep
		all={}
		for i=1,#args do
			v=args[i]
			t=tocs[v]
			if t then
				for i,vv in ipairs(t) do 
					vv.PRE=type(vv.TYPE)=="number" and rep("\t",vv.TYPE) or ""
					t[i]=convert("toc-item",vv) 
				end
			end
			t.CLASS=v
			t.VALUE=concat(t,"\n")
			all[i]=convert("toc-block",t)
		end
		all.VALUE=concat(all,"\n")
		return convert("toc",all)
	end,
	reference=function(str)
		
	end,
	content=function(str)
		str=blocks[str]
		return str and str.VALUE
	end,
}

local format=string.format

process_file=function(cls,filepath,tmplt_dir)
	cls=cls or "html"
	current=dofile(tmplt_dir..cls..".lua")
	cls=current.EXT or cls
	print(format("Reading from %q ...",filepath))
	local tr=file2tree(filepath)
	print("processing...")
	tree2toc(tr)
	local str=obj2str(tr)
	local name=match(filepath,"^(.*)%..-$") or filepath
	filepath=name.."."..cls
	print(format("Writing to %q ...",filepath))
	local f=io.open(filepath,"w")
	if f then f:write(str) f:close() end
	print("Success!")
	f=current.post_process
	if f then -- if there are command needed to running 
		print(format("Processing %q ...",filepath))
		f(name)
	end
end