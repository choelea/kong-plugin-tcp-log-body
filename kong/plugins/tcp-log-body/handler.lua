local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local gkong = kong
local TcpLogHandler = BasePlugin:extend()
TcpLogHandler.PRIORITY = 7
TcpLogHandler.VERSION = "2.0.0"

function TcpLogHandler:new()
  TcpLogHandler.super.new(self, "tcp-log-body")
end

local function get_body_data()
  local req  = ngx.req
  
  req.read_body()
  local data  = req.get_body_data()
  if data then
    return data
  end

  local file_path = req.get_body_file()
  if file_path then
    local file = io.open(file_path, "r")
    data = file:read("*all")
    file:close()
    return data
  end
  
  return ""
end

function TcpLogHandler:access(conf)
  TcpLogHandler.super.access(self)  
  ngx.ctx.accessiable = true  -- used in body filter, as some 404 request, :access will not be invoked
  ngx.ctx.response_body = ""
  ngx.ctx.request_body = get_body_data()
end

function TcpLogHandler:body_filter(conf)
  TcpLogHandler.super.body_filter(self)
  if ngx.ctx.accessiable then -- No need set response for 404 requests (not routes setted requests); for those requests ngx.ctx.response_body is nil
    local chunk = ngx.arg[1]
    ngx.ctx.response_body = ngx.ctx.response_body .. (chunk or "")
  end
end

local function serialize(ngx, kong)
  local ctx = ngx.ctx
  local var = ngx.var

  if not kong then
    kong = gkong
  end

  local request_uri = var.request_uri or ""

  return {
    -- indexname = "bayuquanapp-api-log",
    uri = request_uri,
    url = var.scheme .. "://" .. var.host .. ":" .. var.server_port .. request_uri,
    querystring = kong.request.get_query(), -- parameters, as a table
    method = kong.request.get_method(), -- http method
    reqsize = var.request_length,
    status = var.upstream_uri,
    status = ngx.status,
    ressize = var.bytes_sent,
    reqbody = ctx.request_body,
    resbody = ctx.response_body,
    client_ip = var.remote_addr
  }
end
local function log(premature, conf, message)
    if premature then
      return
    end
  
    local ok, err
    local host = conf.host
    local port = conf.port
    local timeout = conf.timeout
    local keepalive = conf.keepalive
  
    local sock = ngx.socket.tcp()
    sock:settimeout(timeout)
  
    ok, err = sock:connect(host, port)
    if not ok then
      ngx.log(ngx.ERR, "[tcp-log-body] failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
      return
    end
  
    if conf.tls then
      ok, err = sock:sslhandshake(true, conf.tls_sni, false)
      if not ok then
        ngx.log(ngx.ERR, "[tcp-log-body] failed to perform TLS handshake to ",
                         host, ":", port, ": ", err)
        return
      end
    end
  
    ok, err = sock:send(cjson.encode(message) .. "\n")
    if not ok then
      ngx.log(ngx.ERR, "[tcp-log-body] failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
    end
  
    ok, err = sock:setkeepalive(keepalive)
    if not ok then
      ngx.log(ngx.ERR, "[tcp-log-body] failed to keepalive to " .. host .. ":" .. tostring(port) .. ": ", err)
      return
    end
  end
  
  function TcpLogHandler:log(conf)
    local message = serialize(ngx)
    message.indexname = conf.index_name
    local ok, err = ngx.timer.at(0, log, conf, message)
    if not ok then
      ngx.log(ngx.ERR, "[tcp-log-body] failed to create timer: ", err)
    end
  end
return TcpLogHandler
