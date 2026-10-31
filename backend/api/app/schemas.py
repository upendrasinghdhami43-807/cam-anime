from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.alias_generators import to_camel


class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, from_attributes=True)


class StyleOut(CamelModel):
    id: str
    name: str
    version: int
    sort_order: int
    params: dict


class StyleList(CamelModel):
    items: list[StyleOut]


class FeedbackIn(CamelModel):
    message: str = Field(min_length=1, max_length=2000)
    app_version: str = Field(min_length=1, max_length=32)
    device: str | None = Field(default=None, max_length=120)

    @field_validator("message", "app_version")
    @classmethod
    def not_blank(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("must not be blank")
        return value


class FeedbackOut(CamelModel):
    id: str


class ConfigOut(CamelModel):
    api_version: int
    min_app_version: str
    features: dict[str, bool]
