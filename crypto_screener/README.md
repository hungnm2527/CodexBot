# Crypto Screener

A modular Python project for building a daily crypto universe and (later) scoring suggested coins.

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Copy the example environment file if you want to use an API key:

```bash
cp .env.example .env
```

## Configuration

Edit `config.yaml` to control the universe size, throttling, caching, and stablecoin exclusions.

## Run the universe builder

```bash
python -m src.pipelines.universe
```

Output is written to `outputs/universe/universe.csv` and a short summary is printed.
