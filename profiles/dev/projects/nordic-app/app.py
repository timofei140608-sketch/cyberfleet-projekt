"""NordicTech intranet helper — näidis-lähtekood (varundatakse 06_fleet_backup.yml-iga)."""


def vat(amount: float, rate: float = 0.24) -> float:
    """Arvuta käibemaks (Eesti KM 24%)."""
    return round(amount * rate, 2)


if __name__ == "__main__":
    print("KM 100 € pealt:", vat(100))
