==========================
Using Docker Compose
==========================

Configuring
==========================

Create a file called :code:`docker-compose.yml` under e. g. :code:`/opt/mc-server` and add:

.. code-block:: yaml

    version: '2'

    services:
      bungeecord_1:
        image: d3strukt0r/bungeecord
        ports:
          - 25565:25577
        volumes:
          - ./data:/data
        environment:
          - JAVA_MAX_MEMORY=1G

      lobby:
        image: d3strukt0r/spigot
        volumes:
          - ./data:/data
        environment:
          - JAVA_MAX_MEMORY=1G
          - EULA=true

To be able to access the minecraft servers, you need to set the correct address in your
:code:`config.yml`. The address basically is the name of the container. The port is the one that
is configured under :code:`server.properties` inside Spigot (by default :code:`25565`). With the
example above, this would for example look like:

.. code-block:: yaml

    servers:
      lobby:
        motd: '&1Lobby'
        address: spigot:25565
        restricted: false

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
