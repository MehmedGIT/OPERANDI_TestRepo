from pkg_resources import resource_filename
__all__ = [
    "HARVESTER_IP",
    "HARVESTER_PORT",
    "HARVESTER_PATH",
    "VD18_IDS_FILE",
    "VD18_URL",
    "VD18_METS_EXT",
    "WAIT_TIME_BETWEEN_SUBMITS",
    "POST_METHOD_TO_OPERANDI",
    "POST_METHOD_ID_PARAMETER",
    "POST_METHOD_URL_PARAMETER"
]

# These will be relevant if the harvester is deployed to another host
HARVESTER_IP: str = "localhost"
HARVESTER_PORT: int = 27777
HARVESTER_PATH: str = f"http://{HARVESTER_IP}:{HARVESTER_PORT}"

# These are the VD18 constants
VD18_IDS_FILE: str = resource_filename(__name__, "vd18IDs.txt")
VD18_URL: str = "https://gdz.sub.uni-goettingen.de/mets/"
VD18_METS_EXT: str = ".mets.xml"

# Harvesting related constants
# This is the time waited between the POST requests to the OPERANDI Server
WAIT_TIME_BETWEEN_SUBMITS: int = 10  # seconds

# This is the default POST method to OPERANDI
# NOTE: Make sure that the OPERANDI Server's IP and PORT are correctly configured here!!!
POST_METHOD_TO_OPERANDI: str = "http://localhost:8000/vd18_ids/"
POST_METHOD_ID_PARAMETER: str = "vd18_id="
POST_METHOD_URL_PARAMETER: str = "vd18_url="
