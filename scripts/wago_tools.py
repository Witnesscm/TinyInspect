import csv
from io import StringIO

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


class WagoClient:
    def __init__(self, product: str = "wow", retries: int = 3):
        self.product = product
        self._build_cache = {}

        self.session = requests.Session()
        retry_cfg = Retry(
            total=retries,
            backoff_factor=1,
            status_forcelist=[429, 500, 502, 503, 504],
        )
        self.session.mount("https://", HTTPAdapter(max_retries=retry_cfg))

    def fetch_version(self) -> str:
        if self.product not in self._build_cache:
            url = f"https://wago.tools/api/builds/{self.product}/latest"
            try:
                resp = self.session.get(url)
                resp.raise_for_status()
            except requests.RequestException as e:
                raise RuntimeError(f"获取版本信息失败: {url} -> {e}")

            self._build_cache[self.product] = resp.json()["version"]

        return self._build_cache[self.product]

    def fetch_csv(self, name: str, locale: str = "enUS"):
        version = self.fetch_version()
        params = {"build": version, "locale": locale}
        url = f"https://wago.tools/db2/{name}/csv"

        try:
            resp = self.session.get(url, params=params)
            resp.raise_for_status()
        except requests.RequestException as e:
            raise RuntimeError(f"获取 CSV 失败: {url} -> {e}")

        reader = csv.DictReader(StringIO(resp.text))
        return list(reader)
