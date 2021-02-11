require "fog/compute/models/server"

module Fog
  module Ovirt
    class Compute
      class Server < Fog::Compute::Server
        # This will be the instance uuid which is globally unique across
        # a oVirt deployment.
        identity :id

        attribute :name
        attribute :comment
        attribute :description
        attribute :profile
        attribute :display
        attribute :storage, :aliases => "disk_size"
        attribute :creation_time
        attribute :os
        attribute :ip
        attribute :status
        attribute :cores, :aliases => "cpus"
        attribute :sockets
        attribute :memory
        attribute :host
        attribute :cluster
        attribute :template
        attribute :instance_type
        attribute :interfaces
        attribute :volumes
        attribute :raw
        attribute :quota
        attribute :ips
        attribute :ha
        attribute :ha_priority
        attribute :clone
        attribute :disks

        def ready?
          status !~ /down/i
        end

        def locked?
          @volumes = nil # force reload volumes
          !!(status =~ /locked/i) || (attributes[:volumes] = nil) || volumes.any? { |v| !!(v.status =~ /locked/i) }
        end

        def stopped?
          status.casecmp("down").zero?
        end

        def mac
          interfaces.first.mac unless interfaces.empty?
        end

        def interfaces
          @interfaces ||= id.nil? ? [] : Fog::Ovirt::Compute::Interfaces.new(
            :service => service,
            :vm => self
          )
        end

        def add_interface(attrs)
          wait_for { stopped? } if attrs[:blocking]
          service.add_interface(id, attrs)
        end

        def update_interface(attrs)
          wait_for { stopped? } if attrs[:blocking]
          service.update_interface(id, attrs)
        end

        def destroy_interface(attrs)
          wait_for { stopped? } if attrs[:blocking]
          service.destroy_interface(id, attrs)
        end

        def volumes
          @volumes ||= id.nil? ? [] : Fog::Ovirt::Compute::Volumes.new(
            :service => service,
            :vm => self
          )
        end

        def add_volume(attrs)
          wait_for { stopped? } if attrs[:blocking]
          service.add_volume(id, attrs)
        end

        def destroy_volume(attrs)
          wait_for { stopped? } if attrs[:blocking]
          service.destroy_volume(id, attrs)
        end

        def update_volume(attrs)
          wait_for { stopped? } if attrs[:blocking]
          service.update_volume(id, attrs)
        end

        def attach_volume(attrs)
          wait_for { stopped? } if attrs[:blocking]
          service.attach_volume(id, attrs)
        end

        def detach_volume(attrs)
          wait_for { stopped? } if attrs[:blocking]
          service.detach_volume(id, attrs)
        end

        def add_to_affinity_group(attrs)
          wait_for { stopped? } if attrs[:blocking]
          service.add_to_affinity_group(id, attrs)
        end

        def remove_from_affinity_group(attrs)
          wait_for { stopped? } if attrs[:blocking]
          service.remove_from_affinity_group(id, attrs)
        end

        def start(options = {})
          wait_for { !locked? } if options[:blocking]
          vm_power_action(:start)
        end

        def start_with_cloudinit(options = {})
          wait_for { !locked? } if options[:blocking]
          action_status = service.vm_start_with_cloudinit(:id => id, :user_data => fetch_user_data(options))
          reload
          action_status
        end

        def start_with_initialization(options = {})
          wait_for { !locked? } if options[:blocking]
          action_status = service.vm_start_with_initialization(:id => id, :user_data => fetch_user_data(options))
          reload
          action_status
        end

        def stop(_options = {})
          vm_power_action(:stop)
        end

        def reboot(options = {})
          unless stopped?
            stop
            wait_for { stopped? }
          end
          start options.merge(:blocking => true)
        end

        def suspend(_options = {})
          vm_power_action(:suspend)
        end

        def vm_power_action(action)
          action_status = service.vm_action(:id => id, :action => action)
          reload
          action_status
        end

        def destroy(_options = {})
          begin
            (stop unless stopped?)
          rescue StandardError
            nil
          end # ignore failure, destroy the machine anyway.
          wait_for { stopped? }
          service.destroy_vm(:id => id)
        end

        def ticket(options = {})
          raise ::Fog::Ovirt::Errors::OvirtError, "Can not set console ticket, Server is not ready. Server status: #{status}" unless ready?
          service.vm_ticket(id, options)
        end

        def save
          if persisted?
            service.update_vm(attributes)
          else
            self.id = service.create_vm(attributes).id
          end
          reload
        end

        def to_s
          name
        end

        private

        def fetch_user_data(options)
          return { :custom_script => options[:user_data] } if options[:use_custom_script]

          Hash[YAML.safe_load(options[:user_data]).map { |a| [a.first.to_sym, a.last] }]
        end
      end
    end
  end
end
