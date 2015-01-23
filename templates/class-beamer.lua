local concat,gsub=table.concat,string.gsub

local TABLE_PAT=[[
\begin{table}[!hbp]
\centering
\begin{tabular}{@FORMAT@}
@VALUE@
\end{tabular}
\end{table}
]]

local format=string.format

local FIGURE_PAT=[[
\begin{block}{@CAPTION@}
\centering\includegraphics[width=0.5\textwidth]{@VALUE@}
\end{block}
]]

--~ local FIGURES_PAT=[[
--~ \begin{block}{@CAPTION@}
--~ @VALUE@
--~ \end{block}
--~ ]]

local SINGLE_FIG_FMT=[[\centering\includegraphics<%d>[width=0.5\textwidth]{%s}]]
local SINGLE_FIG_FMT=[[
\only<%d>{
\begin{block}{%s}
\centering\includegraphics[width=0.5\textwidth]{%s}
\end{block}
}
]]

local CODE_PAT=	[[
\begin{block}{@CAPTION@}
\lstinputlisting[escapechar=, language=@LANGUAGE@, style=customcode]{@SOURCE@}
\end{block}
]]

local CODE_PART_PAT=	[[
\begin{block}{@CAPTION@}
\lstinputlisting[escapechar=\\, language=@LANGUAGE@, firstline=@FIRSTLINE@, lastline=@LASTLINE@, firstnumber=@FIRSTLINE@, lastnumber=@LASTLINE@, style=customcode]{@SOURCE@}
\end{block}
]]


local SINGLE_LINE_FMT=[[\only<%d>{%s}]]

local TABLE_PAT=[[
\begin{block}{@CAPTION@}
\centering
\begin{table}
\begin{tabular}{@FORMAT@}
@VALUE@
\end{tabular}
\end{table}
\end{block}
]]

local push=table.insert

local EQ_PAT=[[
\begin{block}{@CAPTION@}
\[@VALUE@\] 
\end{block}
]]

local COMPILE_PAT=[[
xelatex -interaction=nonstopmode @name@.tex
xelatex -interaction=nonstopmode @name@.tex
rm @name@.nav @name@.toc @name@.log @name@.aux @name@.out @name@.snm
]]

return {
	EXT='tex',
	OL="\n\\begin{enumerate}\n@VALUE@\n\\end{enumerate}",
	UL="\n\\begin{itemize}\n@VALUE@\n\\end{itemize}",
	LI=[[\item{@VALUE@}]],
	
	TOC="\\tableofcontents",
	TOC_ITEM="",
	TOC_OF_TYPE="",
	
	REFERENCES=[[
\bibliographystyle{plain}
\bibliography{@VALUE@}
]],
	
	[1]="\n\\section{@CAPTION@} \\label{@TYPE@:@ID@}\n@VALUE@",
--~ 	[2]="\n\\subsection{@CAPTION@} \\label{@TYPE@:@ID@}\n@VALUE@",
--~ 	[3]="\n\\subsection{@CAPTION@} \\label{@TYPE@:@ID@}\n@VALUE@",
--~ 	[4]="\n\\subsection{@CAPTION@} \\label{@TYPE@:@ID@}\n@VALUE@",
[2]=[[
\begin{frame}{@CAPTION@}{}
@VALUE@
\end{frame}
]],
	[3]="\n\\begin{block}{@CAPTION@}\n@VALUE@\n\\end{block}",
--~ 	[3]="\n\\begin{columns}\n@VALUE@\n\\end{columns}",
--~ 	[4]="\n\\begin{column}{0.5\\textwidth}\n@VALUE@\n\\end{column}",
--~ 	
--~ 	["SEC*"]="\n\\section*{@CAPTION@} \n@VALUE@",
--~ 	["SUBSEC*"]="\n\\subsection*{@CAPTION@} \n@VALUE@",
--~ 	["SUBSUBSEC*"]="\n\\subsection*{@CAPTION@} \n@VALUE@",
--~ 	["SUBSUBSUBSEC*"]="\n\\subsection*{@CAPTION@}\n@VALUE@",

	['columns']=function(o)
		
	end,

	['block']=[[
\begin{block}{@CAPTION@}
@VALUE@
\end{block}
	]],
	
	['TABLE_ROW']=function(row,i) 
		return concat(row," & ").." \\\\";
	end,
	['TABLE_MAIN']=function(o)
		print("o.FORMAT",o,FORMAT)
		o.FORMAT=o.FORMAT or string.rep("c ",o.COLS)
		o.VALUE="\\hline\n"..o[1].."\n\\hline\n"..concat(o,"\n",2).."\n\\hline"
		return (gsub(TABLE_PAT,"@%s*(.-)%s*@",o))
	end,
	
	timeuse="",
	
	BLOCK="\n\\begin{@TYPE@}\n@VALUE@\n\\end{@TYPE@}",
	
	P="@VALUE@",
	
	code="\\lstinputlisting[language=@1@,style=customcode]{@2@}",
	['code-part']="\\lstinputlisting[language=@1@,style=customcode,firstline=@3@, lastline=@4@, firstnumber=@3@, lastnumber=@4@]{@2@}",
	
	['ref']="\\ref{@TYPE@:@ID@}",
	['em']="\\emph{@0@}",
	-- urls
	['http']="<a href='http:@1@'>@2@</a>",
	['https']="<a href='https:@1@'>@2@</a>",
	['cite']="\\cite{@0@}",
	
	['img']=[[\centering\includegraphics[width={@2@}\textwidth]{@1@}]],
	
	
	['references']="\\bibliographystyle{unsrt}\n\\bibliography{@0@}",
	
	['CODE']=function(o)
		if not o.SOURCE then return end
		o.CAPTION=o.CAPTION or o.SOURCE
		o.LANGUAGE=o.LANGUAGE or "C"
		return (gsub(o.FIRSTLINE and CODE_PART_PAT or CODE_PAT,"@%s*(.-)%s*@",o))
	end,
	
	['eq']=[[\(@0@\)]],
	
	['quote']=[[``@0@'']],
	
	['EQ']=EQ_PAT,

	['FIG']=FIGURE_PAT,
	
	FIGS=function(o)
		local t={}
		local i,offset=0,o.OFFSET or 0
		local oo,src,title={}
		local match=string.match
		for l in string.gmatch(o.VALUE.."\n","(.-)\n") do
			i=i+1
			src,title=match(l,"^%s*(.-)%s*|%s*(.-)%s*$")
			src=src or l; title=title or o.CAPTION
			t[i]=format(SINGLE_FIG_FMT,i+offset,title,src)
		end
--~ 		o.VALUE=table.concat(t,"\n")
--~ 		return gsub(FIGURES_PAT,"@(.-)@",o)
		return table.concat(t,"\n")
	end,
	
	
	TEXT_LINES=function(o)
		local t={}
		local i,offset=0,o.OFFSET or 0
		local oo,src,title={}
		local match=string.match
		for l in string.gmatch(o.VALUE.."\n","(.-)\n") do
			i=i+1
			t[i]=format(SINGLE_LINE_FMT,i+offset,l)
		end
--~ 		o.VALUE=table.concat(t,"\n")
--~ 		return gsub(FIGURES_PAT,"@(.-)@",o)
		return table.concat(t,"\n")
	end,
	
	
	TABLE=function(o)
		local t={}
		local r={}
		local n,rn=0
		local gmatch,insert=string.gmatch,table.insert
		for l in gmatch(o.VALUE.."\n","(.-)\n") do
			n=n+1
			rn=0
			for c in gmatch(l,"([^|]+)") do
				rn=rn+1
				r[rn]=c
			end
			if rn>1 then
				t[n]=table.concat(r,"&",1,rn)..[[\\]]
			end
		end
		if o.ROWLINES=="TRUE" then
			o.VALUE="\\hline\n"..table.concat(t,"\n\\hline\n").."\n\\hline"
		else
			t[1]=t[1].."\n\\hline"
			o.VALUE="\\hline\n"..table.concat(t,"\n").."\n\\hline"
		end
		o.FORMAT=o.FORMAT or string.rep("c",#r)
		return gsub(TABLE_PAT,"@(.-)@",o)
	end,
	
	
	FRAME=[[\begin{frame} 
\frametitle{@CAPTION@}
@VALUE@
\end{frame}]],
	
	[0]=[[
% UTF-8 encoding, compile with XeLaTeX
\documentclass{beamer}




\useoutertheme{wuerzburg}
\useinnertheme[outline, shadow]{chamfered}
\usecolortheme{shark}

\usepackage{tikz}
\usepackage{amsmath}
\usepackage{verbatim}
\usetikzlibrary{arrows,shapes,matrix,calc}

\usepackage{xcolor}

\usetheme{Copenhagen}
\usepackage{beamerthemeBerlin}
\usecolortheme{rose}
\useinnertheme[shadow]{rounded}
\useoutertheme{infolines}


\usepackage{listings}

\lstdefinestyle{customcode}{
  belowcaptionskip=1\baselineskip,
  breaklines=true,
  xleftmargin=20pt,
  frame=single,
  showstringspaces=false,
  numbers=left,                    % where to put the line-numbers; possible values are (none, left, right)
  numbersep=10pt,                   % how far the line-numbers are from the code
  numberstyle=\tiny\color{gray}, % the style that is used for the line-numbers
  basicstyle=\footnotesize\ttfamily,
  keywordstyle=\bfseries\color{blue}, 
  identifierstyle=\color{purple!40!black},
  commentstyle=\itshape\color{green!40!black},
  stringstyle=\color{orange},
}

\usepackage{xeCJK}
\setCJKmainfont{WenQuanYi Micro Hei}




\begin{document}

\setbeamerfont{itemize/enumerate body}{size=\normal}
\setbeamerfont{block title}{size=\normal}

\title{@CLASSNAME@}
\subtitle{@CAPTION@}
\author{@AUTHOR@}
\institute[大连大学信息工程学院]{@INSTITUTE@}
\date{@YEAR@ 学年}   %添加时间 


\frame{  %第一张ppt为标题页
	\titlepage
}


\frame{  %第一张ppt为标题页
	\tableofcontents
}

\AtBeginSection[]
{
        \begin{frame}<beamer>{当前内容}
                \tableofcontents[currentsection]
        \end{frame}
}

@VALUE@
{
\usebackgroundtemplate{%
\parbox[c][\paperheight][c]{\paperwidth}{\centering\tikz\node[opacity=0.1]{\includegraphics[width=0.5\paperwidth]{logo}};}
}
\frame{
	\begin{center}谢谢各位同学！\end{center}
}
}

\end{document}
]],

	["toc"]="",
	["toc-block"]="",
	["toc-item"]="",

	['$']=[[\(@VALUE@\)]],
	['`']="``@VALUE@''",
	['*']="{\\color{red}@VALUE@}",
	
	['pause']=[[\pause]],
	
	post_process=function(name)
--~ 		local f=io.popen(format("xelatex -interaction=nonstopmode %s",name,name,name))
		local str=string.gsub(COMPILE_PAT,"@name@",name)
		local f=io.popen(str)
		if f then
			print(f:read("*a"))
			f:close()
		end
--~ 		local f=os.execute(format("xelatex -interaction=nostopmode %s",name))
	end,

	
}

