local match,len,gmatch,sub=string.match,string.len,string.gmatch,string.sub
local pairs,rawget=pairs,rawget

local SPECIAL_PAT="^(%p+%S*)"
local SECTION_PAT="^%*+$"

local FOLDER_BASE,FOLDER_HEADER,NORMAL=SC_FOLDLEVELBASE,SC_FOLDLEVELHEADERFLAG+SC_FOLDLEVELBASE,SC_FOLDLEVELBASE+20

local BLOCK_BEGIN,BLOCK_END=FOLDER_HEADER+10,FOLDER_BASE+10

local PROPS_STYLE,BLOCK_STYLE,FILE_STYLE,NORMAL_STYLE=10,11,12,0

local inline_table={['$']=21,['!']=22,['*']=23,['#']=24,['`']=25}

local style_line=function(str,s,e,style)
	if s>1 then editor:SetStyling(s-1, style); str=sub(str,s,e); e=e-s+1; s=1; end
	for ss,p,ee in gmatch(str,"()([!#%*%$`])%2.-%2%2()") do
		editor:SetStyling(ss-s, style)
		editor:SetStyling(ee-ss, rawget(inline_table,p) or style)
		s=ee
	end
	if s<=e then editor:SetStyling(e-s+1, style) end
end

local header_table={
	['^%*+()$']=function(str,level)
		if not level then return end
		return FOLDER_HEADER+level-1,level-1
	end,
	["^@%w+()$"]=function(str,level)
		if not level then return end
		return NORMAL,PROPS_STYLE
	end,
	["^%#BEGIN_*(.-)$"]=function(str,level)
		if not level then return end
		return BLOCK_BEGIN,BLOCK_STYLE
	end,
	["^%#END()$"]=function(str,level)
		if not level then return end
		return BLOCK_END,BLOCK_STYLE
	end,
	["^%#FILE()$"]=function(str,level)
		if not level then return end
		return NORMAL,FILE_STYLE 
	end,
}

local str,header,level,style
local lexer=function(line)
	str=editor:GetLine(line)
	if not str then editor.FoldLevel[line]=NORMAL return end
	header=match(str,SPECIAL_PAT)
	if header then  
		for k,v in pairs(header_table) do
			level,style=v(str,match(header,k))
			if level then editor.FoldLevel[line]=level; editor:SetStyling(len(str),style); return end
		end
	end
	style_line(str,1,len(str),NORMAL_STYLE)
	editor.FoldLevel[line]=NORMAL
end

return lexer;