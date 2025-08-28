# This file is now a passthrough to the correct serverless handler.
# This ensures that even if the RunPod environment incorrectly tries
# to run this file as a web server, it will instead start the
# correct serverless worker.

from handler import handler, start

if __name__ == "__main__":
    if start:
        start({"handler": handler})
