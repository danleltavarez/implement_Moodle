"""
Shared pytest fixtures for the Moodle Docker AWS Challenge test suite.

This ``conftest`` module centralises common paths and helpers so that test
modules under the ``tests/`` directory can obtain them through dependency
injection instead of recomputing them inline.

The ``repo_root`` fixture resolves the repository root (the parent of the
``tests/`` directory where this file lives). It is intended for future
tests that need a stable reference to the workspace root.

NOTE: Existing tests keep using ``pathlib.Path(__file__).parent.parent``
directly and continue to work unchanged — this fixture is purely additive.
"""

from pathlib import Path

import pytest
from hypothesis import HealthCheck, settings

# ---------------------------------------------------------------------------
# Hypothesis profile — desabilita o deadline no perfil padrão.
#
# O teste test_git_ignores_sensitive_filenames chama subprocess.run(["git",
# "check-ignore", ...]) para cada exemplo gerado. No Windows, inicializar
# git.exe custa ~300–400 ms na primeira chamada de cada rodada, ultrapassando
# o deadline padrão de 200 ms da Hypothesis (FlakyFailure).
# Em Linux/WSL o mesmo teste passa sem problemas.
# ---------------------------------------------------------------------------
settings.register_profile(
    "default",
    deadline=None,
    suppress_health_check=[HealthCheck.too_slow],
)
settings.load_profile("default")


@pytest.fixture
def repo_root() -> Path:
    """Return the repository root directory as a :class:`pathlib.Path`.

    The repository root is the parent of the ``tests/`` directory that
    contains this ``conftest.py``. Tests can request this fixture to
    locate project artefacts (e.g. ``docker/``, ``terraform/``, ``docs/``)
    without hard-coding absolute paths.
    """
    return Path(__file__).parent.parent
