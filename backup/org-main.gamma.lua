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
			push(stack[top],lst); 			push(stack,lst);
		else
			while #stack>level do pop(stack) end -- pop element deeper than level
			push(stack[level],{TYPE="LI",content})
		end
		return true
	end
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

local BLOCKS={}

local BLOCK_PATTERN="^([%*%@])%**()%s*(.-)%s*$"
local KEY_VALUE_PATTERN="^%s*(%S+)%s*(.-)%s*$"
local file2tree
file2tree=function(path,stack,blocks) -- convert file 'path' to a tree, according to special pattern, including  toc lines and property lines, the top element if the stack 
	local b_level,node=#stack,stack[#stack]
	local BLOCK_PATTERN, KEY_VALUE_PATTERN = BLOCK_PATTERN, KEY_VALUE_PATTERN
	local tag, level, content, key, value
	local match, push, pop= string.match, table.insert, table.remove
--~ 	local stack,top={},tree -- top always point to current node 'tree' or the top of the stack
	for line in io.lines(path) do
		tag,level,content=match(line,BLOCK_PATTERN)
		if tag=="*" then -- process block lines "*.. CAPTION", a block line without CAPTION will end the current level block
			level=level-1 -- there are (level-1) stars
			while #stack>=level+b_level do  process_block(pop(stack)) end -- pop blocks whose level are deeper or equal the current level, while process them before drop them from stack
			if match(content, "%S") then 	-- if CAPTION is meaningful, push it to the parent level node and the stack
				node={CAPTION=content, REF=content, TYPE="SEC"} -- generate block node, the default type is 'SEC'
				push(blocks,node); blocks[content]=node;  -- register current block to 'blocks'
				push(stack[#stack],node); push(stack,node); 	-- add current node to current top node then push it as the top of the stack
				node.LEVEL=#stack-1 -- the level of block is '#stack-1', as the first element is the 0 level node
			end
		elseif tag=="@" then -- process lines with pattern "@ KEY VALUE"
			key, value=match(content,KEY_VALUE_PATTERN)
			if key=="INCLUDE" then
				file2tree(value,stack,blocks)
			elseif key=="PROPS" then
				do_string(value,node)
			elseif key then
				node[key]=value
			end
		else -- normal lines
			push(node,line)
		end
	end
	while #stack>b_level do process_block(pop(stack)) end -- if there are blocks not processed, process them and pop them
	return stack[b_level]
end
--------------------------------------------------------------------------------------------------------------------------------
-- write to file
--------------------------------------------------------------------------------------------------------------------------------
local template

local make_tocs=function(blocks,sep)
	sep=sep or "."
	local tocs={}
	local sec_counters,cur_level={},0
	local tp,level,toc
	local push,concat=table.insert,table.concat
	for i,block in ipairs(blocks) do
		tp,level=block.TYPE,block.LEVEL
		toc=tocs[tp]
		if not toc then toc={}; tocs[tp]=toc end
		push(toc,block)
		if tp=="SEC" then
			for i=cur_level+1,level do sec_counters[i]=0 end
			sec_counters[level]=sec_counters[level]+1
			block.ID=concat(sec_counters,sep,1,level)
			cur_level=level
		else
			block.ID=#toc
		end
	end
	return tocs
end

local ARGS_PATTERN="[^|]+"
local tostring=tostring
local str2args=function(str)
	local args,id={["0"]=str,[0]=str},0
	for w in string.gmatch(str,ARGS_PATTERN) do
		id=id+1; args[id]=w; args[tostring(id)]=w
	end
	return args
end

local REPLACE_PATTERN="@([^\r\n]-)@"
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
	local t={}
	for i,v in ipairs(node) do
		t[i]=parse_tree(v)
	end
	node.VALUE=table.concat(t,"\n")
	return do_key(tp=="SEC" and level or tp,node,template) or  error_in_type(tp)
end

local hooks, TOCS, eval_element, process_string
local match,gsub=string.match, string.gsub

local ELEMENT_KEY_VALUE_PATTERN="^([^:%s]+):(.-)$"
eval_element=function(key,value)
	value=process_string(value)
	if key=="#" then
		local h,arg=match(value,ELEMENT_KEY_VALUE_PATTERN)
		local f=hooks[h] 
		return f and f(arg) or error_in_type(h)
	else
		return do_key(key,value,hooks) or error_in_type(key)
	end
end

local INLINE_ELEMENT_PATTERN="([#`%*%$])%1%s*([^\r\n]-)%s*%1%1"
process_string=function(str)
	str=gsub(str,INLINE_ELEMENT_PATTERN,eval_element)
	return str
end

org2file=function(filepath,cls,tmplt_dir)
	-- reading files
	print("Reading ",filepath,"...")
	local tree={TYPE=0}
	file2tree(filepath,{tree},BLOCKS) -- push 'tree' to the bottom of a stack as the root of the document tree
	TOCS=make_tocs(BLOCKS)
	-- init template and process structure
	cls=cls or "html"
	template=dofile(tmplt_dir..cls..".lua")
	if not template then
		print("Can't load template: ",cls)
		return 
	end
	print("Processing structures ...")
	local str=parse_tree(tree,template,blocks)
	print("Replacing inline elements ...")
	str=process_string(str)
	-- output to file according to 'cls'
	cls=template.EXT or cls
	local name=string.match(filepath,"^(.*)%..-$") 
	local path=name or filepath
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
	local post_process = template.post_process
	if post_process then -- if there are command needed to running 
		print("Post Processing ",path)
		post_process(name)
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
		str=BLOCKS[str]
		return str and do_key("ref",str,template)
	end,
	toc=function(str)
		local args=str2args(str)
		local v,t,all
		local concat,rep=table.concat,string.rep
		all={}
		for i=1,#args do
			v=args[i]
			t=TOCS[v]
			if t then
				for ii,vv in ipairs(t) do 
					vv.PRE=vv.TYPE=="SEC" and rep("\t",vv.LEVEL) or "\t"
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
}
--------------------------------------------------------------------------------------------------------------------------------
-- test or command-line interface
--------------------------------------------------------------------------------------------------------------------------------
--~ org2file("/home/yipf/lua-org/test/lua-org-doc.org","html","/home/yipf/lua-org/templates/")
local cls,path,tmplt_dir=...
assert(path)
cls=cls or "html"
tmplt_dir=tmplt_dir or "/home/yipf/lua-org/templates/"
org2file(path,cls,tmplt_dir)