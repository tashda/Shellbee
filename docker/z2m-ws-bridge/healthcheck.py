import asyncio
import sys
import websockets


async def main():
    try:
        async with websockets.connect("ws://localhost:8080", open_timeout=3):
            pass
    except Exception as e:
        print(f"health check failed: {e}", file=sys.stderr)
        sys.exit(1)


asyncio.run(main())
