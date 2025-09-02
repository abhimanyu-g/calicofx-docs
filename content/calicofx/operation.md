+++
title = "User interaction and operation"
author = ["Abhimanyu G"]
draft = false
weight = 2
+++

During operation, each _lv2 plugin_ instance is wrapped with _Pipewire client_ and connected with _Pipewire daemon_. [Pipewire](https://pipewire.org/) is a low-latency multimedia handling framework in Linux that is aimed to replace [JACK](https://jackaudio.org/) and [pulse-audio](https://www.freedesktop.org/wiki/Software/PulseAudio/) for audio routing.

The user controls the software with web-ui (for now) over websockets and controls

-   Routing(a.k.a Linking)
-   Addition/Deletion
-   Update parameters

In operation, the graph might look something like this

{{< figure src="/ox-hugo/calicofx-flow-graph.png" >}}

Note that,

-   "pw client + fx 'x'" Implies lv2 effect wrapped inside pipewire-client
-   Each effect need not be strictly connected to the previous effect as shown in the diagram, since I follow a graph based routing, node linking is up-to the user's configuration
