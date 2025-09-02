+++
title = "project-goal"
author = ["Abhimanyu G"]
draft = false
weight = 1
+++

Design a guitar effects processing software that is based on server-client mechanism. This software would run on an embedded board and may use the Neural network on the device to generate realistic processing effect. Here is an overview of what I am looking to implement

-   Support lv2 plugins (at least in v1.0)
-   Pipewire backend for all audio routing needs
-   Support Bluetooth overlay for backing track support
-   Front-end has a web interface to interact with the core application

    {{< figure src="/ox-hugo/calicofx-design-overview.png" >}}
