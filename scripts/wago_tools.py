import csv
from pathlib import Path

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


class WagoClient:
    def __init__(self, product: str = "wow", retries: int = 3, force_build: str | None = None):
        self.script_dir = Path(__file__).resolve().parent
        self.cache_dir = self.script_dir / "cache"
        self.cache_dir.mkdir(parents=True, exist_ok=True)

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
                resp = self.session.get(url, timeout=10)
                resp.raise_for_status()
                self._version = resp.json()["version"]
            except requests.RequestException as e:
                raise RuntimeError(f"获取版本信息失败: {url} -> {e}") from e

        return self._version

    def fetch_csv(self, name: str, locale: str = "enUS"):
        build = self.version
        local_dir = self.cache_dir / build

        filename = f"{name}_{locale}.csv"
        local_file = local_dir / filename

        if local_file.exists():
            return self._read_csv(local_file)

        print(f"⬇ 开始下载 CSV：{filename}（build={build}）...")

        params = {"build": build, "locale": locale}
        url = f"https://wago.tools/db2/{name}/csv"

        try:
            resp = self.session.get(url, params=params, timeout=30)
            resp.raise_for_status()
        except requests.RequestException as e:
            raise RuntimeError(f"下载 CSV 失败: {local_file}, {url} -> {e}") from e

        local_dir.mkdir(parents=True, exist_ok=True)
        local_file.write_bytes(resp.content)

        print(f"✅ 下载完成：{filename}，文件大小：{local_file.stat().st_size / (1024 * 1024):.2f} MB")

        return self._read_csv(local_file)

    @staticmethod
    def _read_csv(filepath):
        with open(filepath, "r", encoding="utf-8") as f:
            return list(csv.DictReader(f))
