# Analysis: AI-AutoDev-Platform Architecture

## Topic

Mac-first AI-driven software delivery platform architecture

## Data Type

Technical system architecture — multi-layer distributed system

## Complexity

High — 3 runtime layers, IPC protocol, AI pipeline, domain-driven design

## Tone

Technical / professional

## Audience

Developers, architects, technical leads familiar with macOS/Rust/Swift/Python

## Source Language

Chinese (zh) / English mixed — UI strings in Chinese, code in English

## User Language

Chinese (zh)

## Design Instructions Extracted

- Architecture explanation diagrams (架构解释图)
- Save to project directory
- One or more diagrams covering the full system

## Learning Objectives

1. Understand the 3-layer runtime topology (Swift App / Rust Daemon / Python AI Worker)
2. Understand the IPC communication protocol (Unix socket, line-delimited JSON, envelope pattern)
3. Understand the AI request pipeline (streaming SSE, LangGraph, DeepSeek)
4. Understand the software delivery lifecycle phases and their data flow

## Diagrams Planned

### Diagram 1: System Runtime Topology

Layout: hub-spoke | Style: technical-schematic
Shows: macOS App ↔ Rust Daemon ↔ Python AI Worker ↔ DeepSeek API + SQLite
Aspect: landscape (16:9)

### Diagram 2: IPC Message Flow (Request → Response)

Layout: linear-progression | Style: technical-schematic
Shows: SwiftUI View → ViewModel → DaemonClient → Unix Socket → Router → Store → Response
Aspect: landscape (16:9)

### Diagram 3: Software Delivery Lifecycle

Layout: circular-flow | Style: technical-schematic
Shows: Requirement → PRD → Design → Engineering → Testing → Release → Operations → loop
Aspect: landscape (16:9)
