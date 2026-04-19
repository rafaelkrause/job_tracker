import csv
import io
from datetime import date, datetime

from app.models import Activity


def _format_date(iso_str: str) -> str:
    if not iso_str:
        return ""
    dt = datetime.fromisoformat(iso_str)
    return dt.strftime("%d/%m/%Y")


def _format_time(iso_str: str) -> str:
    if not iso_str:
        return ""
    dt = datetime.fromisoformat(iso_str)
    return dt.strftime("%H:%M")


def export_activities(
    activities: list[Activity], fmt: str, from_date: date, to_date: date
) -> tuple[str, str, str]:
    delimiter = "\t" if fmt == "tsv" else ","
    ext = "tsv" if fmt == "tsv" else "csv"
    mimetype = "text/tab-separated-values" if fmt == "tsv" else "text/csv"

    output = io.StringIO()
    writer = csv.writer(output, delimiter=delimiter)
    writer.writerow(["Data", "Descri\u00e7\u00e3o", "In\u00edcio", "Fim", "Dura\u00e7\u00e3o"])

    for a in activities:
        if a.status != "completed":
            continue
        writer.writerow(
            [
                _format_date(a.started_at),
                a.description,
                _format_time(a.started_at),
                _format_time(a.ended_at) if a.ended_at else "",
                a.effective_duration_formatted(),
            ]
        )

    filename = f"horas_{from_date.strftime('%Y%m%d')}_{to_date.strftime('%Y%m%d')}.{ext}"
    return output.getvalue(), mimetype, filename
