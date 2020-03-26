.. role:: bash(code)
   :language: bash

==========================
Using Docker
==========================

Configuring
==========================

To be able to access BungeeCord, set all :code:`listeners` to :code:`host: 0.0.0.0:<xxxxx>` and
replace the x's with your port. Example:

.. code-block:: yaml

    listeners:
    - ...
      host: 0.0.0.0:25577
      ...

Starting the server
==========================

.. code-block:: bash

   docker run \
      --rm \
      -d \
      -p 25565:25577 \
      -v $(pwd)/data:/data \
      -e JAVA_MAX_MEMORY=1G \
      --name bungeecord_1 \
      d3strukt0r/bungeecord

For the full list of environment variables, refer to :ref:`arguments-overview`.

--rm
--------------------------
Removes the container after it has been shut down. This means we can reuse the name later on.

-d
--------------------------
Start detached. Or leave out to watch the logs. You can then leave using :code:`CTRL` + :code:`D`

.. -i -t (WORK IN PROGRESS)
   --------------------------
   This will let you work with the console inside your container. However, this will not let you
   leave but not re-enter the console, without shutting down the server. Later on, you'll learn a
   workaround for this. To leave from the terminal, and let it run in the background click
   :code:`CTRL + P + Q` (lift from :code:`P` and click :code:`Q` while still holding :code:`CTRL`)

-p 25565:25565
--------------------------
This opens the internal port (inside the container) to the outer worlds. You can open as many
ports as you want. This would maybe look like :bash:`-p 25565:25565 -p 8192:8192`.

-v $(pwd)/\data:/data
--------------------------
If you want to save your server somewhere, you need to link the directory inside your container
to your host. Before the colon goes the place on your host. After the colon goes the directory
inside the container, which is always :code:`/data`.

-e JAVA_MAX_MEMORY=1G
--------------------------
This is the equivalent of :code:`-Xmx1G`. For the required amount of RAM you will need, please
consult Google.

--name bungeecord_1
--------------------------
Give the container a name, for easier referencing later on.

d3strukt0r/bungeecord
--------------------------
This is the repository where the container is maintained. You can also specify what version you
want to use. e. g. :bash:`d3strukt0r/bungeecord:latest` or :bash:`d3strukt0r/bungeecord:548`. For
all versions check the `Tags on Docker Hub`_.

.. _`Tags on Docker Hub`: https://hub.docker.com/repository/docker/d3strukt0r/bungeecord/tags?page=1

.. Using "screen" for reaccessing the console
   ==========================================
   Screen is a Linux program that acts like windows on your desktop, but for the console. So that you
   can close and open console "windows".
   If it's not clear enough yet. This is only possible on Linux systems, not Windows.
   Start by creating a screen and running a server inside:
   .. code-block:: bash
      screen -d -m -S "bungeecord" \
          docker run -it \
              -p 25565:25577 \
              -v $(pwd)/data:/data \
              -e JAVA_MAX_MEMORY=1G \
              d3strukt0r/bungeecord
   screen -d -m -S "bungeecord"
   ----------------------------
   You can detach from the window using :code:`CTRL` + :code:`a` and then :code:`d`.
   To reattach first find your screen with :code:`screen -r`. And if you gave it a name, you can skip
   this.
   Then enter :code:`screen -r bungeecord` or :code:`screen -r 00000.pts-0.office` (or whatever was
   shown with :code:`screen -r`)

Reading the logs
==========================

.. code-block:: bash

   docker logs -f bungeecord_1

-f
--------------------------
The f stands for follow. Which basically means, don't just output the logs until now, but keep
reading, until we exit with :code:`CTRL` + :code:`D`. This will not close the server, you'll just
leave the logs.

Sending commands
==========================

.. code-block:: bash

   docker exec bungeecord_1 console "<command>"

Replace :code:`<command>` with the command you need. This is what you would also usually enter
inside your regular console, like e. g. :code:`op D3strukt0r`.

Stopping the server
==========================

.. code-block:: bash

   docker stop bungeecord_1
