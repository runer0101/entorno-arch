#!/bin/bash
# Bloqueo de pantalla con hyprlock
pidof hyprlock >/dev/null || exec hyprlock
