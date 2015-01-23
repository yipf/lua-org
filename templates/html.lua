local PROP_PAT="@%s*(.-)%s*@"

local TOC="<div id='toc'><center>Table of Contents</center>@VALUE@</div>"
local TOC_ITEM="\n@PRE@@ID@ <a href='#@TYPE@:@ID@'>@CAPTION@</a>"

local gsub,gmatch=string.gsub,string.gmatch

local toc_function=function(tocs)
	local str=tocs.OPT
	if not str then return "" end
	local toc,t,tt,ts
	local push=table.insert
	ts={}
	for k in gmatch(str,"%S+") do
		toc=tocs[k]
		if toc then
			push(ts,k)
			for i=1,#toc do
				push(ts,(gsub(TOC_ITEM,"@%s*(.-)%s*@",toc[i])))
			end
		end
	end
	return (gsub(TOC,PROP_PAT,table.concat(ts,"\n")))
end


local table_row=function(row,i) 
	return i==1 and ("<tr><th>"..table.concat(row,"</th><th>").."</th></tr>") or ("<tr><td>"..table.concat(row,"</td><td>").."</td></tr>")
end
local TABLE="<table id='@TYPE@:@ID@'><caption>@TYPE@.@ID@ @CAPTION@</caption>@VALUE@</table>"

local table_function=function(tbl)
	local pat=tbl.OPT or "[^|]+"
	local t,r={}
	local gmatch,push=string.gmatch,table.insert
	for l in gmatch(tbl.VALUE.."\n","(.-)\n") do
		r={}
		for cell in gmatch(l,pat) do
			push(r,cell)
		end
		push(t,r)
	end
	for i,v in ipairs(t) do
		t[i]=table_row(v,i) 
	end
	tbl.VALUE=table.concat(t,"\n")
	return (gsub(TABLE,PROP_PAT,tbl))
end

return {
	EXT='html',


	BLOCK="\n<@TYPE@ id='@TYPE@:@ID@'>\n@VALUE@\n<@TYPE@>",
	
	-- refs
	
	['cite_element']="<a href='#@TYPE@:@ID@'>@ID@</a>",
	
	REF_FMTS={
		['ARTICLE']=[[<li id='@TYPE@:@ID@'>@AUTHOR@, "@TITLE@", @JOURNAL@, vol. @VOLUME@, no. @NUMBER@, pp.@PAGES@, @YEAR@</li>]],
		['CONFERENCE']=[[<li id='@TYPE@:@ID@'>@AUTHOR@, "@TITLE@", @BOOKTITLE@, pp.@PAGES@, @YEAR@</li>]],
		['INPROCEEDINGS']=[[<li id='@TYPE@:@ID@'>@AUTHOR@, "@TITLE@", @BOOKTITLE@, pp.@PAGES@, @YEAR@</li>]],
	},
	['REFERENCES']="<h1>References</h1>\n<ol id='@NAME@'>@VALUE@<ol>",
	
	['TABLE_ROW']=function(row,i) 
		return i==1 and ("<tr><th>"..table.concat(row,"</th><th>").."</th></tr>") or ("<tr><td>"..table.concat(row,"</td><td>").."</td></tr>")
	end,
	['TABLE_MAIN']="<table id='@TYPE@:@ID@'><caption>@TYPE@.@ID@ @CAPTION@</caption>@VALUE@</table>",
	
	
	
	
	P="\n<p>@VALUE@</p>",
	
	['ref']="<a href='#@TYPE@:@ID@'>@ID@</a>",
	['em']="<strong><em>@1@</em></strong>",
	-- urls
	['http']="<a href='http:@1@'>@2@</a>",
	['https']="<a href='https:@1@'>@2@</a>",
	
	
	['quote']=[["@0@"]],
	
	['CODE']="<div id='@TYPE@:@ID@'><p>@TYPE@.@ID@ @CAPTION@</p>\n<textarea rows=10 cols=100>@VALUE@</textarea>\n</div>",
	
	['eq']=[[\(@0@\)]],
	
	['EQ']="<p id='@TYPE@:@ID@' class='eq'><span class='eq_label'>(@ID@)</span> \\[@VALUE@\\]  </p>",
	
	[0]=[[
	<html>
	<head>
	<title>@CAPTION@</title>
	<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
	<style type="text/css">
	
	body{
	background: #e7e7e7;
	}
	
	ol,ul{
	}
	
	div#toc {
				border: black 3px solid;
				width: 100%;
				white-space: pre-wrap;
	}
	
	.eq {
		border: black 1px solid;'
	}
	
	.eq_label{
		float: right;
	}
	
	.eq_body{
		float: left;
	}
	
		#title {
				font-size: 180%;
	}
	
h1
{
    font-size: 150%; 
/*     border-bottom: #000 1px solid;  */
	border-left: red 12px solid;
}

h2 
{
    font-size: 130%;
/*     border-bottom: #000 1px solid;  */
	border-left: blue 24px solid;
}	
h3
{
    font-size: 110%;
/* 	border-bottom: 1px solid #000000;  */
	border-left: orange 36px solid;
}

h4
{
font-size: 100%;
/* 	border-bottom: 1px solid #000000;  */
	border-left: black 48px solid;
	padding-left: 10px;
}

h5
{
	border-left: black 60px solid;
}

table
{
	bodrder-color:#000;
 border-collapse: collapse;
	border-bottom: 2px solid; 
	border-top: 2px solid; 
 	width: 60%;
		text-align: center;
}

th
{
	border-bottom: 2px solid; 
}



	</style>


<!-- for math type
	<script type="text/javascript" src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML"></script>
-->
	<script type="text/javascript" src="file://localhost/home/yipf/mathjax/MathJax.js?config=TeX-AMS-MML_HTMLorMML"></script>
	</head>
	<body>
	<center id='title'><bold>@CAPTION@</bold></center>
	<center>@AUTHOR@</center>
	<center>@DATE@</center>
	@VALUE@
	</body>
	</html>]],
	
	[1]="\n<h1 id='@TYPE@:@ID@'>@ID@ @CAPTION@</h1>@VALUE@",
	[2]="\n<h2 id='@TYPE@:@ID@'>@ID@ @CAPTION@</h2>@VALUE@",
	[3]="\n<h3 id='@TYPE@:@ID@'>@ID@ @CAPTION@</h3>@VALUE@",
	[4]="\n<h4 id='@TYPE@:@ID@'>@ID@ @CAPTION@</h4>@VALUE@",
	
	---   blocks
	TOC=toc_function,
	
	TABLE=table_function,
	
	['CODE']="<div id='@TYPE@:@ID@'><p>@TYPE@.@ID@ @CAPTION@</p>\n<textarea rows=10 cols=100>@VALUE@</textarea>\n</div>",
	
	['EQ']="<p id='@TYPE@:@ID@' class='eq'><span class='eq_label'>(@ID@)</span> \\[@VALUE@\\]  </p>",
	
	['FIG']=[[<div id='@TYPE@:@ID@'><center><img @OPT@ src='@VALUE@'/></center><center>Figure.@ID@ @CAPTION@</center><div>]],
	
	
	-- inblocks
	
	OL="<ol>@VALUE@</ol>",
	UL="<ul>@VALUE@</ul>",
	LI="<li>@VALUE@</li>",
	
	-- toc items
	["toc"]="<div id='toc'><center>Table of Contents</center>@VALUE@</div>",
	["toc-block"]="@CLASS@\n@VALUE@",
	["toc-item"]="@PRE@@ID@ <a href='#@TYPE@:@ID@'>@CAPTION@</a>",
	
	-- inline elements
	['$']=[[\(@0@\)]], -- inline eq
	['*']="<strong><em>@1@</em></strong>", -- em
	['`']=[["@0@"]], -- quote
	-- urls
	['http']="<a href='http:@1@'>@2@</a>",
	['https']="<a href='https:@1@'>@2@</a>",
	['ref']="<a href='#@TYPE@:@ID@'>@ID@</a>",
	['img']="<img src='@0@'/>",
	

}



