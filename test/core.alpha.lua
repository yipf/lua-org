local match, TERM_PATTERN=string.match, "^%s*(.-)%s*$"
local term=function(str)
	return match(str,TERM_PATTERN)
end

local loadstring, setfenv, _G = loadstring, setfenv, _G
local do_string=function(str,env)
	local f=loadstring(str)
	f= f and setfenv(f,env or _G)
	return f()
end

local self=function(o)
	return o
end

--------------------------------------------------------------------------------------------------------------------------------
-- read from file 
--------------------------------------------------------------------------------------------------------------------------------
local LIST_PATTERN="^%s+()([%d%p]+)%s+(.-)%s*$"
local match=string.match
local valid_list=function(str,stack) -- process current string according the state of 'stack'
	local top=#stack
	local push,pop=table.insert,table.remove
	local level, tag, content=match(str, LIST_PATTERN)
	if level and level>1 and level-top<2 then
		if level==top+1 then
			local lst={TYPE=match(tag,"%d") and "OL" or "UL",{TYPE="LI",content}} 
			push(stack[top],lst)
			push(stack,lst)
		else
			while #stack>level do pop(stack) end
			push(stack[level],{TYPE="LI",content})
		end
		return true
	end
	return false
end

local process_block=function(tbl)  -- only process block of type "SEC"
	if tbl.TYPE~="SEC" then return tbl end
	local new_t={}
	local stack={new_t}
	local v, level, tag, content, top
	local match, push, pop, type= string.match, table.insert, table.remove, type
	for i=1,#tbl do
		v=tbl[i]
		tp=type(v)
		if tp~="string" or (not valid_list(v, stack)) then  -- if not a valid list string
			while #stack>1 do pop(stack) end  -- if there are valid lists, pop them all
			v= tp=="table" and v or tp=="string" and match(v,"%S") and {TYPE="P", term(v)} -- strings are treated as P(Paragraph) elements, ignoring empty lines.
			if v then push(new_t,v) end
		end
	end
	for i,v in ipairs(new_t) do tbl[i]=v end 	-- update elements in tbl
	for i=#new_t+1, #tbl do pop(tbl) end 	-- drop elements after tbl[#new_t]
	return tbl
end

local BLOCK_PATTERN="^([%*%@])%**()%s*(.-)%s*$"
local KEY_VALUE_PATTERN="^%s*(%S+)%s*(.-)%s*$"
local file2tree
file2tree=function(path,tree,tl) -- convert file 'path' to a tree, according to special pattern, including  toc lines and property lines
	tree= tree or {}
	tl=tl or 0
	local BLOCK_PATTERN, KEY_VALUE_PATTERN = BLOCK_PATTERN, KEY_VALUE_PATTERN
	local tag, level, content, key, value
	local match, push, pop= string.match, table.insert, table.remove
	local stack,top={},tree -- top always point to current node 'tree' or the top of the stack
	for line in io.lines(path) do
		tag,level,content=match(line,BLOCK_PATTERN)
		if tag=="*" then -- process block lines "*.. CAPTION", a block line without CAPTION will end the current level block
			level=level-1
			while #stack>=level do  process_block(pop(stack)) end -- pop blocks whose level are deeper or equal the current level, while process them before drop them from stack
			if match(content, "%S") then 	-- if CAPTION is meaningful, push it to the parent level node and the stack
				top={CAPTION=content, REF=content, TYPE="SEC"}
				push(stack[#stack] or tree,top)
				push(stack,top)
				top.LEVEL=tl+#stack
			end
		elseif tag=="@" then -- process lines with pattern "@ KEY VALUE"
			key, value=match(content,KEY_VALUE_PATTERN)
			if key=="INCLUE" then
				file2tree(value,top,top.LEVEL)
			elseif key=="PROPS" then
				do_string(value,top)
			elseif key then
				top[key]=value
			end
		else -- normal lines
			push(top,line)
		end
	end
	while #stack>0 do process_block(pop(stack)) end
	return tree
end
--------------------------------------------------------------------------------------------------------------------------------
-- write to file
--------------------------------------------------------------------------------------------------------------------------------

local hooks, tocs, template

local make_tocs=function(str)
	local t={REFS={}}
	for w in string.gmatch(str,"%w+") do
		t[w]={}
	end
	return t
end

local make_counter=function(sep)
	sep=sep or "."
	local concat,type=table.concat,type
	local ids,level={},0
	return function(key)
		if type(key)=="number" then
			for i=level+1,key do ids[i]=0 end
			ids[key]=ids[key]+1
			level=key
			return concat(ids,sep,1,key)
		else
			if not ids[key] then ids[key]=0 end
			ids[key]=ids[key]+1
			return ids[key]
		end
	end
end

local toc_counter=make_counter(".")

local ARGS_PATTERN="[^|]+"
local tostring=tostring
local str2args=function(str)
	local args,id={["0"]=str,[0]=str},0
	for w in string.gmatch(str,ARGS_PATTERN) do
		id=id+1; args[id]=w; args[tostring(id)]=w
	end
	return args
end

local REPLACE_PATTERN="@(.-)@"
local do_key=function(key,value,ref) -- to do something according to element in table'template' with name 'key' 
	local e=template[key] or template['BLOCK']
	local tp=type(e)
	if tp=="string" then
		return string.gsub(e,REPLACE_PATTERN,value)
	elseif tp=="function" then
		return e(value)
	end
end

local error_in_type=function(tp)
	return "[[ ERROR occured while processing type: "..tp.." ]]"
end

local concat,push,type=table.concat,table.insert,type

local parse_tree 
parse_tree=function(node, template)
	if type(node)=="string" then return node end
	local tp,level=node.TYPE,node.LEVEL
	-- register node to tocs
	local toc=tocs[tp]
	if toc then 
		node.ID=toc_counter(tp=="SEC" and level or tp)
		push(toc,node)
		tocs.REFS[node.REF]=node
	end
	-- process node
	local t={}
	for i,v in ipairs(node) do
		t[i]=parse_tree(v)
	end
	node.VALUE=table.concat(t,"\n")
	return do_key(tp=="SEC" and level or tp,node,template) or  error_in_type(tp)
end

local eval_element, process_string
local match,gsub=string.match, string.gsub

local ELEMENT_KEY_VALUE_PATTERN="^([^:%s]+):(.-)$"
eval_element=function(key,value)
	value=process_string(value)
	if key=="#" then
		local h,arg=match(value,ELEMENT_KEY_VALUE_PATTERN)
		h=hooks[h]
		return h and h(arg) or error_in_type(h)
	else
		return do_key(key,value,hooks) or error_in_type(key)
	end
end

local INLINE_ELEMENT_PATTERN="([#`%*%$])%1%s*(.-)%s*%1%1"
process_string=function(str)
	str=gsub(str,INLINE_ELEMENT_PATTERN,eval_element)
	return str
end

org2file=function(filepath,cls,tmplt_dir)
	-- reading files
	print("Reading ",filepath,"...")
	local tree=file2tree(filepath)
	tree.TYPE=0
	tocs=make_tocs(tree.TOC or "SEC")
	-- init template and process structure
	cls=cls or "html"
	template=dofile(tmplt_dir..cls..".lua")
	if not template then
		print("Can't load template: ",cls)
		return 
	end
	print("Processing structures ...")
	local str=parse_tree(tree,template)
	print("Replacing inline elements ...")
	str=process_string(str)
	-- output to file according to 'cls'
	cls=template.EXT or cls
	local path=string.match(filepath,"^(.*)%..-$") or filepath
	path=path.."."..cls
	local f=io.open(path,"w")
	if not f then
		print("Can't create file: ",path)
	else
		print("Writing to ",path,"...")
		f:write(str)
		print("Success!")
		f:close()
	end
end

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
		str=tocs.REFS[str]
		return str and do_key("ref",str,template)
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
				for ii,vv in ipairs(t) do 
					vv.PRE=vv.TYPE=="SEC" and rep("\t",vv.LEVEL) or ""
					t[ii]=do_key("toc-item",vv,template) 
				end
				t.CLASS=v
				t.VALUE=concat(t,"\n")
				all[i]=do_key("toc-block",t,template)
			else
				all[i]=""
			end
		end
		all.VALUE=concat(all,"\n")
		return do_key("toc",all,template)
	end,
	cite=function(str)
		
	end,
}

-- test
org2file("/home/yipf/lua-org/test/lua-org-doc.org","html","/home/yipf/lua-org/templates/")

