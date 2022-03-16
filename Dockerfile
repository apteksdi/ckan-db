###################
### Extensions ####
###################
FROM ghcr.io/kangmoesss/docker-ckan:v1 as extbuild

# Locations and tags, please use specific tags or revisions
ENV HARVEST_GIT_URL=https://github.com/ckan/ckanext-harvest
ENV HARVEST_GIT_BRANCH=v1.3.1
ENV PAGES_GIT_URL=https://github.com/ckan/ckanext-pages.git
ENV PAGES_GIT_BRANCH=master
ENV SHOWCASE_GIT_URL=https://github.com/ckan/ckanext-showcase.git
ENV SHOWCASE_GIT_BRANCH=master
#ENV SPATIAL_GIT_URL=https://github.com/ckan/ckanext-spatial.git
#ENV SPATIAL_GIT_BRANCH=master
ENV GEOVIEW_GIT_URL=https://github.com/ckan/ckanext-geoview.git
ENV GEOVIEW_GIT_BRANCH=master

# Switch to the root user
USER root

# Install necessary packages to build extensions
RUN apk add --no-cache tzdata \
	libxml2 \
        libxslt \
	libxml2-dev \
        libxslt-dev \
	libc-dev \
	musl-dev \
	geos \
	binutils \
        gcc \
        g++ \
        libffi-dev \
        openssl-dev \
        python3-dev \
        rust \
        cargo \
	proj \
	proj-dev \
	proj-util \
	libffi-dev \
	libtool \
	libmagic

# Fetch and build the custom CKAN extensions
RUN pip wheel --wheel-dir=/wheels git+${HARVEST_GIT_URL}@${HARVEST_GIT_BRANCH}#egg=ckanext-harvest
RUN pip wheel --wheel-dir=/wheels -r https://raw.githubusercontent.com/ckan/ckanext-harvest/${HARVEST_GIT_BRANCH}/pip-requirements.txt
RUN curl -o /wheels/harvest.txt https://raw.githubusercontent.com/ckan/ckanext-harvest/${HARVEST_GIT_BRANCH}/pip-requirements.txt

RUN pip wheel --wheel-dir=/wheels git+${PAGES_GIT_URL}@${PAGES_GIT_BRANCH}#egg=ckanext-pages
RUN pip wheel --wheel-dir=/wheels -r https://raw.githubusercontent.com/ckan/ckanext-pages/${PAGES_GIT_BRANCH}/requirements.txt
RUN curl -o /wheels/pages.txt https://raw.githubusercontent.com/ckan/ckanext-pages/${PAGES_GIT_BRANCH}/requirements.txt

RUN pip wheel --wheel-dir=/wheels git+${SHOWCASE_GIT_URL}@${SHOWCASE_GIT_BRANCH}#egg=ckanext-showcase
RUN pip wheel --wheel-dir=/wheels -r https://raw.githubusercontent.com/ckan/ckanext-showcase/${SHOWCASE_GIT_BRANCH}/requirements.txt
RUN curl -o /wheels/showcase.txt https://raw.githubusercontent.com/ckan/ckanext-showcase/${SHOWCASE_GIT_BRANCH}/requirements.txt

#RUN pip wheel --wheel-dir=/wheels git+${SPATIAL_GIT_URL}@${SPATIAL_GIT_BRANCH}#egg=ckanext-spatial
#RUN pip wheel --wheel-dir=/wheels -r https://raw.githubusercontent.com/ckan/ckanext-spatial/${SPATIAL_GIT_BRANCH}/requirements.txt
#RUN curl -o /wheels/spatial.txt https://raw.githubusercontent.com/ckan/ckanext-spatial/${SPATIAL_GIT_BRANCH}/requirements.txt

RUN pip wheel --wheel-dir=/wheels git+${GEOVIEW_GIT_URL}@${GEOVIEW_GIT_BRANCH}#egg=ckanext-geoview
RUN pip wheel --wheel-dir=/wheels -r https://raw.githubusercontent.com/ckan/ckanext-geoview/${GEOVIEW_GIT_BRANCH}/pip-requirements.txt
RUN curl -o /wheels/geoview.txt https://raw.githubusercontent.com/ckan/ckanext-geoview/${GEOVIEW_GIT_BRANCH}/pip-requirements.txt

USER ckan

############
### MAIN ###
############
FROM ghcr.io/kangmoesss/docker-ckan:v1

LABEL maintainer="Kang Moes <kangmoes777@gmail.com>"

ENV CKAN__PLUGINS envvars image_view text_view recline_view datastore datapusher harvest ckan_harvester pages showcase resource_proxy geojson_view recline_grid_view recline_map_view recline_graph_view
ENV CKANEXT__PAGES__ALLOW_HTML True
ENV CKANEXT__PAGES__EDITOR ckeditor
ENV CKANEXT__SHOWCASE__EDITOR ckeditor
ENV CKAN__AUTH__CREATE_USER_VIA_API false
ENV CKAN__AUTH__CREATE_USER_VIA_web false
ENV CKAN__VIEWS__DEFAULT_VIEWS geo_view geojson_view
ENV CKANEXT__GEOVIEW__OL_VIEWER__FORMATS geojson wms kml

# Switch to the root user
USER root

COPY --from=extbuild /wheels /srv/app/ext_wheels

# Install and enable the custom extensions
RUN pip install --no-index --find-links=/srv/app/ext_wheels ckanext-harvest && \
    pip install --no-index --find-links=/srv/app/ext_wheels -r /srv/app/ext_wheels/harvest.txt && \
    pip install --no-index --find-links=/srv/app/ext_wheels ckanext-pages && \
    pip install --no-index --find-links=/srv/app/ext_wheels -r /srv/app/ext_wheels/pages.txt && \
    pip install --no-index --find-links=/srv/app/ext_wheels ckanext-showcase && \
    pip install --no-index --find-links=/srv/app/ext_wheels -r /srv/app/ext_wheels/showcase.txt && \
    #pip install --no-index --find-links=/srv/app/ext_wheels ckanext-spatial && \
    #pip install --no-index --find-links=/srv/app/ext_wheels -r /srv/app/ext_wheels/spatial.txt && \
    pip install --no-index --find-links=/srv/app/ext_wheels ckanext-geoview && \
    pip install --no-index --find-links=/srv/app/ext_wheels -r /srv/app/ext_wheels/geoview.txt && \

    # Configure plugins
    ckan config-tool "${APP_DIR}/production.ini" "ckan.plugins = ${CKAN__PLUGINS}" && \
    ckan config-tool "${APP_DIR}/production.ini" "ckanext.pages.allow_html = ${CKANEXT__PAGES__ALLOW_HTML}" && \
    ckan config-tool "${APP_DIR}/production.ini" "ckanext.pages.editor = ${CKANEXT__PAGES__EDITOR}" && \
    ckan config-tool "${APP_DIR}/production.ini" "ckanext.showcase.editor = ${CKANEXT__SHOWCASE__EDITOR}" && \
    ckan config-tool "${APP_DIR}/production.ini" "ckan.auth.create_user_via_api = ${CKAN__AUTH__CREATE_USER_VIA_API}" && \
    ckan config-tool "${APP_DIR}/production.ini" "ckan.auth.create_user_via_web = ${CKAN__AUTH__CREATE_USER_VIA_WEB}" && \
    ckan config-tool "${APP_DIR}/production.ini" "ckan.views.default_views = ${CKAN__VIEWS__DEFAULT_VIEWS}" && \
    ckan config-tool "${APP_DIR}/production.ini" "ckanext.geoview.ol_viewer_formats = ${CKANEXT__GEOVIEW__OL_VIEWER__FORMATS}" && \
    
    chown -R ckan:ckan /srv/app

# Remove wheels
RUN rm -rf /srv/app/ext_wheels

# Add harvest afterinit script
COPY ./afterinit.d/00_harvest.sh ${APP_DIR}/docker-afterinit.d/00_harvest.sh

# Switch to the ckan user
USER ckan

