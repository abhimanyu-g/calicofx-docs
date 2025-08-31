+++
title = "calico-fx design"
author = ["Abhimanyu G"]
draft = false
+++

## Goal {#goal}

Design a guitar effects processing software that is based on server-client mechanism. This software would run on an embedded board and may use the Neural network on the device to generate realistic processing effect. Here is an overview of what I am looking to implement

-   Support lv2 plugins (at least in v1.0)
-   Pipewire backend for all audio routing needs
-   Support Bluetooth overlay for backing track support
-   Front-end has a web interface to interact with the core application

    {{< figure src="/ox-hugo/calicofx-design-overview.png" >}}


## Operation {#operation}

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


## Class Diagram {#class-diagram}


### Overview {#overview}

The overall class structure looks something like below. We enforce _pipewire_ as the media manager but the plugins although is _lv2_ now, can change in the future to support more plugin types. Hence, the plugins are abstracted

{{< figure src="/ox-hugo/calicofx-overview-class-dig.png" >}}


### session-manager {#session-manager}

Session manager is responsible to

-   Add/Remove new pw-clients as nodes
-   Access stored nodes for params changes
-   Link/unlink between multiple nodes/pw-clients
-   Save and restore session ( &gt; v1.0)

There would always be utmost 1 Session manager instance

{{< figure src="/ox-hugo/calicofx-session-mgr-class-dig.png" >}}


### pw-client {#pw-client}

Since we use threaded main loop in our pw_client, all operations must happen within [pw_thread_loop_lock()](https://docs.pipewire.org/group__pw__thread__loop.html#gaa7996893e812e9eec61f786d1c691c54) and [pw_thread_loop_unlock()](https://docs.pipewire.org/group__pw__thread__loop.html#ga1f8042dce9da459ec61b6f3a2d6852d8)


#### Common static structures {#common-static-structures}

Following are the common structures that are _file-static_ and share with all the dynamically created clients. It is initialized once at the start of the program during [Initialization](#initialization)

-   `pw_thread_loop *loop`
-   `pw_context *context`
-   `pw_core *core`

During [De-initialize](#de-initialize), The above allocations are cleared

-   `loop` with [pw_thread_loop_stop()](https://docs.pipewire.org/group__pw__thread__loop.html#ga856c3aec5718bceb92d6169c42062186) and [pw_thread_loop_destroy()](https://docs.pipewire.org/group__pw__thread__loop.html#ga58bf781b6f987e80d4a7a6796551dfb1)
-   `context` with [pw_context_destroy()](https://docs.pipewire.org/group__pw__context.html#ga41fdab6368603144f0911541182713a1)
-   `core` with [pw_core_disconnect()](https://docs.pipewire.org/group__pw__core.html#gaa0ad30957ad355b5217f161cc7847c2f)


#### class details {#class-details}

{{< figure src="/ox-hugo/calicofx-pw-client-class-dig.png" >}}

<!--list-separator-->

-  `pwInitClient`

    Init client initializes the pw-client and wraps the underlying plugin to provide a seamless abstraction to the above layers. The underlying plugin can be any of the supported types
    (refer [Plugin Base](#plugin-base) and [Adding a node](#adding-a-node) for more information).

<!--list-separator-->

-  `pwLinkClientPorts`

    Links (a.k.a connects) the Source's output port to the Destination's input port. It utilizes the _impl_ APIs and calls [pw_context_create_link](https://docs.pipewire.org/group__pw__impl__link.html#ga7d7c433db2954a961e4980a37168dc6d) inside.
    It needs to be a static function (probably outside the class) as it operates on more than one pw-client

<!--list-separator-->

-  `pwUnlinkClientPorts`

    Unlinks (a.k.a disconnects) 2 ports.

    -   Find the port using [pw_impl_node_find_port](https://docs.pipewire.org/group__pw__impl__node.html#ga07267b71d5bbdf5312af836b240b4dab) from the src/dst UUID and src/dst PortIdx. This works because we would have set `port-id` as the port-index from the plugin desc
    -   Instead of storing the link structure, we would find it on the go using [pw_impl_link_find](https://docs.pipewire.org/group__pw__impl__link.html#ga9dec6e3bcc59c5d9e7fb70bf36f86dd8) passing the ports found in the previous step
    -   Destroy it using [pw_impl_link_destroy](https://docs.pipewire.org/group__pw__impl__link.html#ga3baed016411a9a3d0f7407c3a9144b39)

<!--list-separator-->

-  `~PipewireClient`

    Destruct Pipewire client object and destroy underlying plugin instance and filter object

    -   Calls base plugin's destruct function
    -   Disconnects filter from the main-loop with [pw_filter_disconnect()](https://docs.pipewire.org/group__pw__filter.html#ga913200b5d552335932cfe145bdf2a3e6)
    -   Destroys the filter with [pw_filter_destroy()](https://docs.pipewire.org/group__pw__filter.html#gaf54752a2edef1c569fdfb8e6774b4ead)

<!--list-separator-->

-  Processing

    Apart from the above global variables, the [processing of plugin](https://docs.pipewire.org/structpw__filter__events.html#a324db3b12bbac07c495395eae521e97a) will be a common callback function. This is because all of the plugins have to perform following functionality in the sequence

    -   Get ports with [pw_filter_get_dsp_buffer()](https://docs.pipewire.org/group__pw__filter.html#gaf86eb47b3adbca1ddfb66235a8a5ae69). Do note that this only works as we register the node as a DSP media role
    -   [Connect the ports](#pluginconnectport) via Plugin Base and underlying plugin specific mechanism
    -   Run the plugin instance with [pluginRun](#pluginrun)

    During the addition of ports, the port_ID of the pw_client was configured to be the same as the port's index of the plugin. The same shall be used to connect the ports.
    Also during the filter creation using [pw_filter_new_simple()](https://docs.pipewire.org/group__pw__filter.html#gafff846bdbb4f52cac93f27a19c073e05), an opaque pointer for the user data was passed. This user data is mostly a reference to _pluginMgr_ of the class. The same would be passed to process callback


### Plugin Base {#plugin-base}

Plugin base is an abstract class which provides the interface to pipewire client class. This helps to interface various plugin types (vst, ladspa, clap...).
For the v1.0, we would be supporting only _lv2_ type plugins

This class would solely be controlled by [pw-client](#pw-client). Hence, there is an instance of _Plugin base_ for every instance of _pw-client_

{{< figure src="/ox-hugo/calicofx-plugin-base-class-dig.png" >}}


#### LV2-manager {#lv2-manager}

Class responsible to manage lv2 specific operation. I.e,

-   Parsing the plugins to fetch plugin description (ports, number and type of controls, metadata etc...)
-   Instantiating and un-instantiating a plugin
-   Run a plugin instance for every sample

{{< figure src="/ox-hugo/calicofx-lv2-manager-class-dig.png" >}}

<!--list-separator-->

-  `pluginUpdateParam`

    `pluginUpdateParam` will internally call [lilv_instance_connect_port](https://drobilla.net/docs/lilv/index.html#c.lilv_instance_connect_port) from the _lilv_ library to connect a control port of the current instance to a value and update it, therefore updating the plugin instance's port value.

<!--list-separator-->

-  `pluginDeactivate` and `pluginDestroy`

    Both are called at the termination of the [pw_client](#pipewireclient). `pluginDeactivate` for lv2 calls [lilv_instance_deactivate()](https://drobilla.net/docs/lilv/index.html#c.lilv_instance_deactivate) to deactivate the active instance of lv2 plugin and `pluginDestroy` calls [lilv_instance_free()](https://drobilla.net/docs/lilv/index.html#c.lilv_instance_free) to free the instance's resources.

<!--list-separator-->

-  `pluginConnectPort`

    pluginConnectPort tries to connect the shared buffer to the plugin's port. The lv2 class override of this function calls [lilv_instance_connect_port()](https://drobilla.net/docs/lilv/index.html#c.lilv_instance_connect_port) internally.

<!--list-separator-->

-  `pluginRun`

    Run an instance of the plugin using the call to [lilv_instance_run()](https://drobilla.net/docs/lilv/index.html#c.lilv_instance_run). The process the input buffer according to the plugin's DSP and provides it at the output


## Detailed flow {#detailed-flow}


### Initialization {#initialization}

Initialization refers to the global initialization and is expected to be called **only once** during the start of the program, there is also a [de-initialize](#de-initialize) counterpart which does the opposite

{{< figure src="/ox-hugo/calicofx-initialization.png" >}}


### Adding a node {#adding-a-node}

{{< figure src="/ox-hugo/calicofx-adding-a-node.png" >}}


### Updating a control value {#updating-a-control-value}

{{< figure src="images/calicofx-update-control-param.png" >}}


### Linking ports {#linking-ports}

Linking ports refer to connection 2 ports in-order to let their data flow from one plugin to another or source to input of a plugin or plugin to the output.
I have made the decision to not have any assumption about the connection and is left to the user preference. I.e

-   No assumption is made to pre-connect ports when a new plugin is added.
-   No assumption on how the ports are connected one-to-one, one-to-many, many-to-many

However, to establish a link between 2 ports, it is required that the _source port_ is plugin A's `output port` and the _sink port_ is plugin B's `input port`.

{{< figure src="/ox-hugo/calicofx-link-ports.png" >}}


### Processing audio {#processing-audio}

Processing audio refers to handling the callback from the pipewire client. It involves connecting the input and output buffers to the appropriate ports of the underlying plugin and running the instance of that plugin to perform the intended audio effect on that input buffer and make the processed audio available on the output buffer.

This is performed over and over all the plugin instances a.k.a pw-client nodes.

Pipewire provides a [process](https://docs.pipewire.org/structpw__filter__events.html#a324db3b12bbac07c495395eae521e97a) callback feature that is called for each pw-client filter node.
In each callback, the sequence of events looks like below.

{{< figure src="/ox-hugo/calicofx-process-callback.png" >}}


### Unlink ports {#unlink-ports}

Unlinking refers to removing the previously established link between pw-clients

{{< figure src="/ox-hugo/calicofx-unlink-ports.png" >}}


### Removing a node {#removing-a-node}

{{< figure src="/ox-hugo/calicofx-removing-a-node.png" >}}


### De-initialize {#de-initialize}

De-initialization is the final clean-up before closing the _calicofx_ application. It does opposite of what [Initialization](#initialization) does. As _calicofx_ is planned to run as a service, De-initialization is triggered on receiving any system level signals (`SIGINT` or `SIGTERM`)

{{< figure src="/ox-hugo/calicofx-de-initialization.png" >}}
