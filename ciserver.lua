local server_port = 8888
local api_secret = "secret"
local ci_script = "./dispatch.sh"
local log_dir = "./log/"


local ffi = require "ffi"
ffi.cdef[[
struct _IO_FILE;
typedef struct _IO_FILE FILE; 

FILE *popen(const char *command, const char *type);
int fileno(FILE *stream);
int pclose(FILE *stream);
]]

local band, bor, rsh = bit.band, bit.bor, bit.rshift
local C = ffi.C

TURBO_SSL = true
local turbo = require "turbo"
local ioloop = turbo.ioloop.instance()


local SubProcess = class("SubProcess")

function SubProcess:initialize(cmd, bufsize)
	bufsize = bufsize or 16*1024
	self.buf = ffi.new('char[?]', bufsize)
	self.pipe = C.popen(cmd, "r")
	self.pipefd = C.fileno(self.pipe)
	turbo.socket.set_nonblock_flag(self.pipefd)
	ioloop:add_handler(self.pipefd, bor(turbo.ioloop.READ, turbo.ioloop.ERROR),
		self._eventHandler, self)
end

function SubProcess:_eventHandler(fd, events)
	if band(events, turbo.ioloop.READ) ~= 0 then
		local n = C.read(fd, self.buf, ffi.sizeof(self.buf))
		local data = ffi.string(self.buf, n)
		self:recv(data)
	end
	if band(events, turbo.ioloop.ERROR) ~= 0 then
		ioloop:remove_handler(fd)
		local status = C.pclose(self.pipe)
		local termsig = band(status, 0x7f)
		local exitcode = band(rsh(status, 8), 0xff)
		self:exit(termsig, exitcode)
	end
end


local CIProcess = class("CIProcess", SubProcess)

function CIProcess:initialize(taskqueue, task)
	self.taskqueue = taskqueue
	self.task = task
	self.logfile = io.open(log_dir..task.commit..".txt", "w")
	local cmd = ci_script.." "..task.commit
	SubProcess.initialize(self, cmd)
end

function CIProcess:recv(data)
	self.logfile:write(data)
end

function CIProcess:exit(termsig, exitcode)
	self.logfile:write(
		string.format("\n\n** Terminated with signal=%d, exitcode=%d\n",
			termsig, exitcode)
	)
	self.logfile:close()

	local indexfile = io.open(log_dir.."index", "a")
	local commit = self.task.commit
	local status = (termsig == 0 and exitcode == 0) and "OK" or "FAIL"
	indexfile:write(
		string.format('<a href="%s.txt">%s</a> %s<br />\n',
			commit, commit, status)
	)
	indexfile:close()

	self.taskqueue.curtask = nil
	self.taskqueue:dispatch()
end


local TaskQueue = class("TaskQueue", turbo.structs.deque)

function TaskQueue:enqueue(task)
	self:appendleft(task)
	if not self.curtask then
		self:dispatch()
	end
end

function TaskQueue:dispatch()
	local task = self:pop()
	if not task then return end
	self.curtask = CIProcess:new(self, task)
end

local taskqueue = TaskQueue:new()


local GitHubHandler = class("GitHubHandler", turbo.web.RequestHandler)

function GitHubHandler:authcheck()
	local signature = self.request.headers:get("X-Hub-Signature")
	if signature ~= "sha1="..turbo.hash.HMAC(api_secret, self.request.body) then
		error(turbo.web.HTTPError(401, "Unauthorized"))
	end
end

function GitHubHandler:post()
	self:authcheck()
	local event = self.request.headers:get("X-GitHub-Event")
	local body = turbo.escape.json_decode(self.request.body)
	if event == "push" then
		self:pushevent(body)
	end
end

function GitHubHandler:pushevent(body)
	local commit = body.after
	if commit:match("[^0-9a-f]") then
		error(turbo.web.HTTPError(403, "Invalid commit identifier"))
	end
	taskqueue:enqueue({commit = commit})
end


local LogIndexHandler = class("LogIndexHandler", turbo.web.RequestHandler)

function LogIndexHandler:get()
	local file = io.open(log_dir.."index", "r")
	self:write('<div style="font-family: monospace">\n')
	self:write(file:read("*a"))
	self:write('</div>')
	file:close()
end


local application = turbo.web.Application:new({
	{"^/push_hook$", GitHubHandler},
	{"^/log/index", LogIndexHandler},
	{"^/log/(.*)$", turbo.web.StaticFileHandler, log_dir}
})

application:listen(server_port, nil, {
	ssl_options = {
		key_file = "./sslkeys/server.key",
		cert_file = "./sslkeys/server.crt"
	}
})

ioloop:start()
