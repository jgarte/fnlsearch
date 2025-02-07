#!/usr/bin/env lua5.4

local _M = {}

--
-- Methods that are set on the returned parsed object, for evaluating
-- if a specific user agent is allowed to continue.
--
local _methods = {}

function _methods.set_agent( this, agent )
	--
	-- Reset state if needed
	--
	if this.agent_set then
		rawset( this, 'current_agent', nil )
	end

	--
	-- Find one.
	--
	for name in pairs(this.agents) do
		if agent:match(name) then
			rawset( this, 'current_agent', name )
		end
	end

	rawset( this, 'agent_set', true )

end

function _methods.check_allowed( this, url )
	assert(this.agent_set, "Provide user-agent first")

	local rules = this.agents[ this.current_agent ]
	local all_rules = this.agents['*']
	local matches = {}

	if rules then
		for i, v in ipairs(rules.allow) do	-- luacheck: ignore 213
			if url:match(v) then
				matches[ #matches + 1 ] = {
					rule = v,
					url = url:match(v),
					result = true
				}
			end
		end

		for i, v in pairs(rules.deny) do	-- luacheck: ignore 213
			if url:match(v) then
				matches[ #matches + 1 ] = {
					rule = v,
					url = url:match(v),
					result = false
				}
			end
		end
	end

	for i, v in pairs(all_rules.allow) do	-- luacheck: ignore 213
		if url:match(v) then
			matches[ #matches + 1 ] = {
				rule = v,
				url = url:match(v),
				result = true
			}
		end
	end

	for i, v in pairs(all_rules.deny) do	-- luacheck: ignore 213
		if url:match(v) then
			matches[ #matches + 1 ] = {
				rule = v,
				url = url:match(v),
				result = false
			}
		end
	end

	if #matches == 0 then
		return true
	end

	table.sort(matches, function( a, b )
		if #(a.rule) == #(b.rule) then
			return #(a.url) > #(b.url)
		end

		return #(a.rule) > #(b.rule)
	end)

	return matches[1].result
end




--
-- Hybrid LPEG parser. LPEG handles the tokenizing, conventional
-- Lua code later assembles the parsed data structure.
--
local lp = require 'lpeg'

local function set_directive( s )

	local ret = lp.P(true)

	s:gsub('.', function(c)
		ret = ret * (lp.P(c:lower()) + lp.P(c:upper()))
	end)

	return ret * lp.Cc(s) * lp.P(':')
end


lp.locale( lp )

local p_Any = lp.P('*')
local p_All = lp.P(1)^1
local p_String = (lp.alnum + lp.S('_-/:*') + lp.space)
local p_Number = lp.C(lp.digit^1)

local p_Agent = lp.C(p_String^1 + p_Any)
local p_Url = lp.C(p_All)

local d_Agent = set_directive('User-agent')
local d_Delay = set_directive('Crawl-delay')
local d_Allow = set_directive('Allow')
local d_Disallow = set_directive('Disallow')
local d_SiteMap = set_directive('SiteMap')

local l_Agent = d_Agent * lp.space * p_Agent
local l_Allow = d_Allow * lp.space * p_Url
local l_Disallow = d_Disallow * lp.space * p_Url
local l_SiteMap = d_SiteMap * lp.space * p_Url
local l_Delay = d_Delay * lp.space * p_Number

local Line = l_Agent + l_Allow + l_Disallow + l_SiteMap + l_Delay



--
-- Convert robots.txt patters into Lua patterns.
--
local function pattern( url )

	if url:sub(#url) == '*' then
		url = url:sub(1, #url - 1)
	end

	url = url:gsub('%%', '%%%%')
	url = url:gsub('%.', '%%.')
	url = url:gsub('%*', '.*')
	url = url:gsub('%?', '%%?')
	url = url:gsub('%+', '%%+')
	url = url:gsub('%-', '%%-')
	url = url:gsub('%{', '%%{')
	url = url:gsub('%}', '%%}')

	url = '^' .. url
	return url

end


---
-- Build a new clean robotstxt object.
--
local function constructor()
	return {
		agents = {
			['*'] = {
				allow = {},
				deny = {}
			}
		},
		crawldelay = 0,
		sitemaps = {},
		agent_set = false,
		current_agent = '*',
		line_number = 1
	}
end


local function parse( txt, line )
	local directive, value = Line:match(line)

	if directive then
		if directive == 'User-agent' then
			txt.current_agent = value
			txt.agents[value] = {
				allow = {},
				deny = {}
			}
		elseif directive == 'Allow' then
			if txt.current_agent then
				local pos = #(txt.agents[txt.current_agent].allow)
				txt.agents[txt.current_agent].allow[pos + 1] = pattern(value)
			end
		elseif directive == 'Disallow' then
			if txt.current_agent then
				local pos = #(txt.agents[txt.current_agent].deny)
				txt.agents[txt.current_agent].deny[pos + 1] = pattern(value)
			end
		elseif directive == 'SiteMap' then
			txt.sitemaps[ #(txt.sitemaps) + 1 ] = value
		elseif directive == 'Crawl-delay' then
			txt.crawldelay = tonumber(value)
		else
			-- impossible case, if lpeg doesn't match we get nil
			-- and thus never get to this if-elseif block.
			-- luacov: disable
			error("Unknown directive - line " .. tostring(txt.line_number))
			-- luacov: enable
		end
	end

	txt.line_number = txt.line_number + 1
end




---
-- Lua part of the hybrid parser.
--
-- Can parse a robots.txt directly from a stream - from, for example,
-- the response body of a lua-http call.
--
function _M.load_stream( stream )

	local ret = constructor()

	for line in stream:lines() do
		parse( ret, line )
	end

	ret.current_agent = nil
	ret.line_number = nil
	setmetatable(ret, { __index = _methods })
	return ret

end


---
-- Load a robots.txt from a table, one directive per line. Mostly
-- intended by unit tests but could be useful.
--
function _M.load_table( tab )

	local ret = constructor()

	for i, line in ipairs(tab) do	-- luacheck: ignore 213
		parse( ret, line )
	end

	ret.current_agent = nil
	ret.line_number = nil
	setmetatable(ret, { __index = _methods })
	return ret

end


---
-- Load a robots.txt from a file. Provide the filename, returns an
-- object. Throws error if the file cannot be opened.
--
function _M.load( file )

	local f = assert(io.open(file, "r"))
	local ret = _M.load_stream( f )
	f:close()
	return ret

end


return _M
