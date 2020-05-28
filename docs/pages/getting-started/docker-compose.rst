==========================
Using Docker Compose
==========================

Configuring
==========================

Create a file called :code:`docker-compose.yml` under e. g. :code:`/opt/mc-server` and add:

.. code-block:: yaml

    version: "2"

    services:
      bungeecord_1:
        image: d3strukt0r/bungeecord
        ports:
          - 25565:25577
        networks:
          - internal
        dns:
          - 1.1.1.1
          - 1.0.0.1
        volumes:
          - ./bungeecord:/data
        environment:
          - JAVA_MAX_MEMORY=512M

      lobby_1:
        image: d3strukt0r/spigot
        networks:
          - internal
        dns:
          - 1.1.1.1
          - 1.0.0.1
        volumes:
          - ./lobby:/data
        environment:
          - JAVA_MAX_MEMORY=1G
          - EULA=true
          - BUNGEECORD=true

    networks:
      internal:
        external: false


To be able to access the minecraft servers, you need to set the correct address in your
:code:`config.yml`. The address basically is the name of the container. The port is the one that
is configured under :code:`server.properties` inside Spigot (by default :code:`25565`). With the
example above, this would for example look like:

.. code-block:: yaml

    ...
    servers:
      lobby:
        motd: '&1Lobby'
        address: lobby_1:25565
        restricted: false
    ...

Also IP needs to be forwared:

.. code-block:: yaml

    ...
    ip_forward: true
    ...

Starting the server
==========================

.. code-block:: bash

    docker-compose up -d

Reading the logs
==========================

.. code-block:: bash

   docker-compose logs -f

Sending commands
==========================

.. code-block:: bash

    docker-compose exec bungeecord_1 console "<command>"

Stopping the server
==========================

.. code-block:: bash

   docker-compose down
