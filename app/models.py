from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional
import uuid


@dataclass
class Pause:
    paused_at: str
    resumed_at: Optional[str] = None

    def duration_seconds(self) -> float:
        start = datetime.fromisoformat(self.paused_at)
        end = (
            datetime.fromisoformat(self.resumed_at)
            if self.resumed_at
            else datetime.now().astimezone()
        )
        return (end - start).total_seconds()

    def to_dict(self) -> dict:
        d = {"paused_at": self.paused_at}
        if self.resumed_at:
            d["resumed_at"] = self.resumed_at
        return d

    @classmethod
    def from_dict(cls, data: dict) -> "Pause":
        return cls(paused_at=data["paused_at"], resumed_at=data.get("resumed_at"))


@dataclass
class Activity:
    id: str
    description: str
    started_at: str
    status: str  # "active", "paused", "completed"
    ended_at: Optional[str] = None
    pauses: list[Pause] = field(default_factory=list)

    @staticmethod
    def create(description: str) -> "Activity":
        return Activity(
            id=str(uuid.uuid4()),
            description=description,
            started_at=datetime.now().astimezone().isoformat(),
            status="active",
        )

    def pause(self):
        if self.status != "active":
            raise ValueError("Can only pause an active activity")
        self.pauses.append(
            Pause(paused_at=datetime.now().astimezone().isoformat())
        )
        self.status = "paused"

    def resume(self):
        if self.status != "paused":
            raise ValueError("Can only resume a paused activity")
        if self.pauses and self.pauses[-1].resumed_at is None:
            self.pauses[-1].resumed_at = datetime.now().astimezone().isoformat()
        self.status = "active"

    def stop(self):
        if self.status == "completed":
            raise ValueError("Activity is already completed")
        if self.status == "paused" and self.pauses and self.pauses[-1].resumed_at is None:
            self.pauses[-1].resumed_at = datetime.now().astimezone().isoformat()
        self.ended_at = datetime.now().astimezone().isoformat()
        self.status = "completed"

    def effective_duration_seconds(self) -> float:
        start = datetime.fromisoformat(self.started_at)
        end = (
            datetime.fromisoformat(self.ended_at)
            if self.ended_at
            else datetime.now().astimezone()
        )
        total = (end - start).total_seconds()
        pause_total = sum(p.duration_seconds() for p in self.pauses)
        return max(0, total - pause_total)

    def effective_duration_formatted(self) -> str:
        seconds = int(self.effective_duration_seconds())
        hours, remainder = divmod(seconds, 3600)
        minutes, secs = divmod(remainder, 60)
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "description": self.description,
            "started_at": self.started_at,
            "ended_at": self.ended_at,
            "status": self.status,
            "pauses": [p.to_dict() for p in self.pauses],
        }

    @classmethod
    def from_dict(cls, data: dict) -> "Activity":
        return cls(
            id=data["id"],
            description=data["description"],
            started_at=data["started_at"],
            ended_at=data.get("ended_at"),
            status=data["status"],
            pauses=[Pause.from_dict(p) for p in data.get("pauses", [])],
        )
