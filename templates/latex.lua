local concat,gsub,format=table.concat,string.gsub,string.format

local TABLE_PAT=[[
\begin{table}[!hbp]
\centering
\begin{tabular}{@FORMAT@}
@VALUE@
\end{tabular}
\caption{\label{@TYPE@:@ID@}@CAPTION@}
\end{table}
]]

local FIGURE_PAT=[[
\begin{figure}[!htb]
\centering
\includegraphics{@VALUE@}
\caption{\label{@TYPE@:@ID@}@CAPTION@}
\end{figure}
]]

local EQ_PAT=[[
\begin{equation} \label{@TYPE@:@ID@}
@VALUE@
\end{equation}
]]

local refs=function(str)
	return format([[
\bibliographystyle{plain}
\bibliography{%s}
]],str)
end


local TABLE= {
	EXT='tex',
	OL="\n\\begin{enumerate}\n@VALUE@\n\\end{enumerate}",
	UL="\n\\begin{itemize}\n@VALUE@\n\\end{itemize}",
	LI=[[\item{@VALUE@}]],
	
	TOC="\\tableofcontents",
	TOC_ITEM="",
	TOC_OF_TYPE="",
	
	REFERENCES=refs,
	
	["SEC*"]="\n\\section*{@CAPTION@} \n@VALUE@",
	["SUBSEC*"]="\n\\subsection*{@CAPTION@} \n@VALUE@",
	["SUBSUBSEC*"]="\n\\subsection*{@CAPTION@} \n@VALUE@",
	["SUBSUBSUBSEC*"]="\n\\subsection*{@CAPTION@}\n@VALUE@",
	
	['TABLE_ROW']=function(row,i) 
		return concat(row," & ").." \\\\";
	end,
	['TABLE_MAIN']=function(o)
		o.FORMAT=o.FORMAT or string.rep("c ",o.COLS)
		o.VALUE="\\hline\n"..o[1].."\n\\hline\n"..concat(o,"\n",2).."\n\\hline"
		return (gsub(TABLE_PAT,"@%s*(.-)%s*@",o))
	end,
	
	BLOCK="\n\\begin{@TYPE@}\n@VALUE@\n\\end{@TYPE@}",
	
	P="@VALUE@",
	
	
	['em']="\\emph{@0@}",
	-- urls
	['http']="<a href='http:@1@'>@2@</a>",
	['https']="<a href='https:@1@'>@2@</a>",
	['cite']="\\cite{@0@}",
	['ref']="\\ref{@TYPE@:@ID@}",
	
	['CODE']="CODE.@ID@ @CAPTION@ \\label{@TYPE@:@ID@}",
	
	['EQ']=EQ_PAT,

	['FIG']=FIGURE_PAT,
	
	[0]=[[
\documentclass{article}
\usepackage{hyperref}
\usepackage{graphicx}
\usepackage{listings}
\usepackage{xcolor}
\usepackage{amsfonts}
\usepackage{amsmath}
\usepackage{cite}

\title{@CAPTION@}
\author{@AUTHOR@}
\date{@DATE@}

\begin{document}
\maketitle
@VALUE@
\bibliographystyle{plain}
\bibliography{@REFS@}
\end{document}]],

	[1]="\n\\section{@CAPTION@} \\label{@TYPE@:@ID@}\n@VALUE@",
	[2]="\n\\subsection{@CAPTION@} \\label{@TYPE@:@ID@}\n@VALUE@",
	[3]="\n\\subsection{@CAPTION@} \\label{@TYPE@:@ID@}\n@VALUE@",
	[4]="\n\\subsubsection{@CAPTION@} \\label{@TYPE@:@ID@}\n@VALUE@",

	['$']=[[\(@0@\)]], -- inline eq
	['*']="\\emph{@0@}", -- em
	['`']=[["@0@"]], -- quote
	
	["toc"]="\\tableofcontents",
	["toc-block"]="",
	["toc-item"]="",
	
	post_process=function(name)
		local f=io.popen(format("latex %s && bibtex %s && latex %s",name,name,name))
		if f then
			print(f:read("*a"))
			f:close()
		end
	end,
	
}


return TABLE
