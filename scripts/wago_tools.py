import os
import csv
from io import StringIO

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


class WagoClient:
    def __init__(self, product="wow", retries=3, force_build=None):
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        self.cache_dir = os.path.join(self.script_dir, "cache")
        os.makedirs(self.cache_dir, exist_ok=True)

        self.product = product
        self._version = force_build
        self.session = requests.Session()
        retry_cfg = Retry(
            total=retries, backoff_factor=1, status_forcelist=[429, 500, 502, 503, 504]
        )
        self.session.mount("https://", HTTPAdapter(max_retries=retry_cfg))

    @property
    def version(self) -> str:
        if self._version is None:
            url = f"https://wago.tools/api/builds/{self.product}/latest"
            try:
                resp = self.session.get(url)
                resp.raise_for_status()
            except requests.RequestException as e:
                raise RuntimeError(f"获取版本信息失败: {url} -> {e}")

            self._version = resp.json()["version"]

        return self._version

    def fetch_csv(self, name: str, locale: str = "enUS"):
        build = self.version
        local_dir = os.path.join(self.cache_dir, build)

        filename = f"{name}_{locale}.csv"
        local_file = os.path.join(local_dir, filename)

        if os.path.exists(local_file):
            return self._read_csv(local_file)

        print(f"⬇ 下载 CSV：{filename}（build={build}）")

        params = {"build": build, "locale": locale}
        url = f"https://wago.tools/db2/{name}/csv"

        try:
            resp = self.session.get(url, params=params)
            resp.raise_for_status()
        except Exception as e:
            raise RuntimeError(
                f"无法下载 CSV（且本地无缓存）: {local_file}, {url} -> {e}"
            )

        os.makedirs(local_dir, exist_ok=True)
        with open(local_file, "w", encoding="utf-8") as f:
            f.write(resp.text)

        return list(csv.DictReader(StringIO(resp.text)))

    @staticmethod
    def _read_csv(filepath):
        with open(filepath, "r", encoding="utf-8") as f:
            return list(csv.DictReader(f))
