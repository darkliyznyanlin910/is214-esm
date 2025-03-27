# Base from odoo official image 
FROM odoo:17.0
# Copy requirements file into the container. Could be also mount.
COPY requirements.in /requirements.in
# Install other addons from requirements
RUN pip install -r /requirements.in
# Copy script which initialize the database (odoo -i)
COPY ./entrypoint-dbbase /entrypoint-dbbase
# Copy script which reset the password of the admin user
COPY ./reset-password /reset-password
