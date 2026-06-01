"""Typed exceptions used by the host app."""


class HostAppError(Exception):
    """Base class for host-app errors."""

    code = 1


class ConfigError(HostAppError):
    code = 2


class ProtocolError(HostAppError):
    code = 12


class TransportError(HostAppError):
    code = 10


class TransportTimeout(TransportError):
    code = 10


class ReadbackMismatch(HostAppError):
    code = 11


class RegisterAccessError(HostAppError):
    code = 2


class UnsafeOperationError(HostAppError):
    code = 20
