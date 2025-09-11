import csv
from io import StringIO

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

session = requests.Session()
retries = Retry(
    total=3,
    backoff_factor=1,
    status_forcelist=[429, 500, 502, 503, 504],
)
session.mount("https://", HTTPAdapter(max_retries=retries))

build_cache = {}


def fetch_version(product="wow"):
    if product not in build_cache:
        url = f"https://wago.tools/api/builds/{product}/latest"
        try:
            resp = session.get(url)
            resp.raise_for_status()
        except requests.RequestException as e:
            raise RuntimeError(f"获取版本信息失败: {url} -> {e}")

        data = resp.json()
        build_cache[product] = data["version"]

    return build_cache[product]


def fetch_csv(name, product="wow", locale="enUS"):
    version = fetch_version(product)
    params = {"build": version, "locale": locale}
    url = f"https://wago.tools/db2/{name}/csv"

    try:
        resp = session.get(url, params=params)
        resp.raise_for_status()
    except requests.RequestException as e:
        raise RuntimeError(f"获取 CSV 失败: {url} -> {e}")

    reader = csv.DictReader(StringIO(resp.text))
    return list(reader)
