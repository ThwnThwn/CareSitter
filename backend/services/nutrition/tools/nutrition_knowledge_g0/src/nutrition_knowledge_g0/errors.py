class G0Error(RuntimeError):
    """Expected, user-actionable G0 failure."""


class ContractError(G0Error):
    """A source, fixture, model response, or frozen configuration is invalid."""


class GateError(G0Error):
    """A fail-closed G0 gate rejected the requested operation."""
