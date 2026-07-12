# Map Rendering and Data Delivery Architecture

> **Status:** Draft normative architecture.
>
> **Implementation status:** Renderer, tile server, and publication pipeline not yet selected or benchmarked.

## Purpose

The map must remain smooth on modest workstations without creating unbounded workstation, server, database, or network load.

## Rendering boundary

The server publishes bounded geographic facts and tiles. The workstation renders the visible map locally using its graphics capability.

The normal path must not require the server to render a new image for every pan, zoom, or resource movement.

## Static and dynamic separation

Mostly static GIS data includes:

- Roads and address references.
- Boundaries and response areas.
- Buildings and selected infrastructure.
- Water and terrain references.

Static data should be simplified by zoom, published as versioned vector tiles or another bounded tile format, and cached aggressively.

Dynamic overlays include:

- Current resource locations.
- Active incidents.
- Hazards, closures, perimeters, and staging points.

Dynamic changes must update only the affected objects and must not regenerate base-map tiles because a unit moved.

## GIS publication boundary

Authoritative GIS source tables and map-publication data should remain distinct.

Publication views or schemas should contain only:

- Required geometry.
- Required attributes.
- Approved simplification.
- Approved classification.
- Approved governed scope.

A map request must not become broad direct access to authoritative or protected operational tables.

## Client cache

The client may cache:

- Versioned base-map tiles.
- Styles, fonts, and icons.
- Approved offline map packages.
- Short-lived authorized operational state.

Cached operational data remains subject to authorization, classification, expiry, clearing, and local-storage policy.

## Degraded operation

The base map and approved reference data should remain available when the live subscription or central tile service is temporarily unavailable, subject to version and age indicators.

Live resource markers must show delayed or stale state. A recovered historical point must not appear live.

## Imagery

Aerial imagery should not be the default operational layer because of storage, bandwidth, cache, and rendering costs. It may be an approved optional layer for workflows that justify those costs.

## Technology direction

MapLibre GL JS, OpenLayers, or another mature renderer may be evaluated. Selection requires testing with actual governed GIS data and the lowest supported workstation profile. The architecture must not depend on an external commercial map service for normal operation unless a separate decision explicitly accepts that dependency.
