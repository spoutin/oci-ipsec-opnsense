import asyncio
import tornado.web
import json
import traceback


async def run_command(cmd):
    proc = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE)

    stdout, stderr = await proc.communicate()
    if proc.returncode:
        raise tornado.web.HTTPError(500, stderr.decode())
    return stdout.decode()


class MainHandler(tornado.web.RequestHandler):
    def write_error(self, status_code, **kwargs):
        self.set_header('Content-Type', 'application/json')
        lines = []
        for line in traceback.format_exception(*kwargs["exc_info"]):
            lines.append(line)
        self.finish(json.dumps({
            'error': {
                'code': status_code,
                'message': self._reason,
                'traceback': lines,
            }
        }))
        
    async def post(self):
        response = await run_command("unset http_proxy && unset https_proxy && ./recreate-ipsec.sh")
        self.write(response)

class HealthHandler(tornado.web.RequestHandler):
    def get(self):
        self.write(json.dumps({"health": "OK"}))

def make_app():
    return tornado.web.Application([
        (r"/recreate-ipsec", MainHandler),
        (r"/health", HealthHandler),
    ])

async def main():
    app = make_app()
    app.listen(8888)
    await asyncio.Event().wait()

if __name__ == "__main__":
    asyncio.run(main())