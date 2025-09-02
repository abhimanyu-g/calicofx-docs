+++
title = "Detailed code flow"
author = ["Abhimanyu G"]
draft = false
weight = 4
+++

## Initialization {#initialization}

Initialization refers to the global initialization and is expected to be called **only once** during the start of the program, there is also a [de-initialize](#de-initialize) counterpart which does the opposite

{{< figure src="/ox-hugo/calicofx-initialization.png" >}}


## Adding a node {#adding-a-node}

{{< figure src="/ox-hugo/calicofx-adding-a-node.png" >}}


## Updating a control value {#updating-a-control-value}

{{< figure src="/ox-hugo/calicofx-update-control-param.png" >}}


## Linking ports {#linking-ports}

Linking ports refer to connection 2 ports in-order to let their data flow from one plugin to another or source to input of a plugin or plugin to the output.
I have made the decision to not have any assumption about the connection and is left to the user preference. I.e

-   No assumption is made to pre-connect ports when a new plugin is added.
-   No assumption on how the ports are connected one-to-one, one-to-many, many-to-many

However, to establish a link between 2 ports, it is required that the _source port_ is plugin A's `output port` and the _sink port_ is plugin B's `input port`.

{{< figure src="/ox-hugo/calicofx-link-ports.png" >}}


## Processing audio {#processing-audio}

Processing audio refers to handling the callback from the pipewire client. It involves connecting the input and output buffers to the appropriate ports of the underlying plugin and running the instance of that plugin to perform the intended audio effect on that input buffer and make the processed audio available on the output buffer.

This is performed over and over all the plugin instances a.k.a pw-client nodes.

Pipewire provides a [process](https://docs.pipewire.org/structpw__filter__events.html#a324db3b12bbac07c495395eae521e97a) callback feature that is called for each pw-client filter node.
In each callback, the sequence of events looks like below.

{{< figure src="/ox-hugo/calicofx-process-callback.png" >}}


## Unlink ports {#unlink-ports}

Unlinking refers to removing the previously established link between pw-clients

{{< figure src="/ox-hugo/calicofx-unlink-ports.png" >}}


## Removing a node {#removing-a-node}

{{< figure src="/ox-hugo/calicofx-removing-a-node.png" >}}


## De-initialize {#de-initialize}

De-initialization is the final clean-up before closing the _calicofx_ application. It does opposite of what [Initialization](#initialization) does. As _calicofx_ is planned to run as a service, De-initialization is triggered on receiving any system level signals (`SIGINT` or `SIGTERM`)

{{< figure src="/ox-hugo/calicofx-de-initialization.png" >}}
