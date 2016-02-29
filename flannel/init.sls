{% from "flannel/map.jinja" import flannel with context %}
{% set settings = salt['pillar.get']('flannel:lookup:settings', {}) %}
{% set flannel_version = "0.5.5" -%}

flannel_install:
  archive.extracted:
    - name: {{ flannel.tmp_dir }}
    - source: https://github.com/coreos/flannel/releases/download/v{{ flannel_version }}/flannel-{{ flannel_version }}-linux-amd64.tar.gz
    - source_hash: sha1=fab60fdf23b029fa39badc008fe951bce5046caa
    - archive_format: tar 
    - tar_options: v
    - user: nobody
    - group: nobody
    - keep: False
    - if_missing: {{ flannel.config_dir }}/.flannel_{{ flannel_version }}

  file.copy:
    - name: {{ flannel.prefix }}/bin/flanneld
    - source: {{ flannel.tmp_dir }}/flannel-{{ flannel_version }}/flanneld
    - user: root
    - group: root
    - mode: 0775
    - force: True
    - onchanges:
      - archive: flannel_install

flannel_install_version:
  file.touch:
    - name: {{ flannel.config_dir }}/.flannel_{{ flannel_version }}
    - makedirs: True
    - require:
      - archive: flannel_install
      - file: flannel_install

flannel_install_cleanup:
  file.absent:
    - name: {{ flannel.tmp_dir }}/flannel-{{ flannel_version }}
    - require:
      - file: flannel_install

flannel_config:
  pkg.installed:
    - python-etcd

  etcd.set:
    - name: /coreos.com/network/config
    - value: '{ "Network": "{{ settings.get('network', '172.16.0.0/12') }}", "Backend": { "Type": "vxlan", "VNI": 1 } }'
    - profile: etcd_local
    - require:
      - pkg: flannel_config

flannel_service:
  file.managed:
    - name: /etc/systemd/system/flannel.service
    - source: salt://flannel/files/flannel.service
    - user: root
    - group: root
    - mode: 0644

  service.running:
    - name: flannel
    - enable: True
    - watch:
      - file: flannel_install
      - file: flannel_service
      - etcd: flannel_config

flannel_docker:
  file.managed:
    - name: /etc/systemd/system/docker.service.d/subnet.conf
    - source: salt://flannel/files/subnet.conf
    - user: root
    - group: root
    - mode: 0644
    - require:
      - service: flannel_service

  service.running:
    - name: docker
    - enable: True
    - watch:
      - file: flannel_docker
