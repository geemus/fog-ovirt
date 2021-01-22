require "active_support"
require "active_support/core_ext"

module Fog
  module Ovirt
    class Compute
      class V4 < Fog::Service
        requires   :ovirt_username, :ovirt_password
        recognizes :ovirt_url,      :ovirt_server, :ovirt_port, :ovirt_api_path, :ovirt_datacenter,
                   :ca_file, :public_key, :api_version, :ovirt_ca_cert_store
        request_path "fog/ovirt/requests/compute/v4"

        request :vm_action
        request :vm_start_with_cloudinit
        request :destroy_vm
        request :create_vm
        request :update_vm
        request :datacenters
        request :storage_domains
        request :list_virtual_machines
        request :get_virtual_machine
        request :list_templates
        request :get_template
        request :list_instance_types
        request :get_instance_type
        request :list_clusters
        request :get_cluster
        request :add_interface
        request :destroy_interface
        request :update_interface
        request :list_vm_interfaces
        request :list_template_interfaces
        request :list_networks
        request :vm_ticket
        request :list_vm_volumes
        request :list_template_volumes
        request :list_volumes
        request :add_volume
        request :get_volume
        request :destroy_volume
        request :update_volume
        request :get_api_version
        request :list_quotas
        request :get_quota
        request :list_operating_systems
        request :list_vnic_profiles

        module Shared
          # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          # converts an OVIRT object into an hash for fog to consume.
          def shared_ovirt_attrs(obj)
            opts = {}
            # TODO: stop using instance_variables, they will change
            obj.instance_variables.each do |v|
              key = v.to_s.delete("@").to_sym
              value = obj.instance_variable_get(v)

              if key == :network
                opts[key] = obj.vnic_profile.present? ? yield(obj) : value
                next
              end

              if key == :provisioned_size
                opts[:size] = value.to_s
                next
              end

              # ignore nil values
              next if value.nil?

              opts[key] = value.id if key != :data_center && value.respond_to?(:href) && value.href && value.respond_to?(:id)

              opts[key] ||= get_attr_value(value, opts)
            end
            opts
          end

          # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

          # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          def get_attr_value(value, opts)
            case value
            when OvirtSDK4::List
              value.to_a
            when Array, Hash, DateTime
              value
            when OvirtSDK4::HighAvailability
              opts[:ha] = value.enabled
              value
            when OvirtSDK4::TemplateVersion
              OpenStruct.new(:version_name => value.version_name, :version_number => value.version_number)
            when OvirtSDK4::Mac
              value.address
            when OvirtSDK4::Cpu
              opts[:cores] = value.topology.nil? ? nil : value.topology.cores
              opts[:sockets] = value.topology.nil? ? nil : value.topology.sockets
            when OvirtSDK4::Display
              subject = value.certificate.subject if value.certificate
              {
                :type => value.type,
                :address => value.address,
                :port => value.port,
                :secure_port => value.secure_port,
                :keyboard_layout => value.keyboard_layout,
                :subject => subject,
                :monitors => value.monitors
              }
            when OvirtSDK4::Console
              { :enabled => value.enabled }
            else
              if value.class.respond_to?(:module_parent) && value.class.module_parent == OvirtSDK4
                value.id if value.respond_to?(:id)
              else
                value.to_s.strip
              end
            end
          end
          # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

          def convert_string_to_bool(value)
            case value
            when "true"
              true
            when "false"
              false
            when Array
              value.map { |elem| convert_string_to_bool(elem) }
            when Hash
              value.each do |key, elem|
                value[key] = convert_string_to_bool(elem)
              end
              value
            else
              value
            end
          end
        end

        class Mock
          include Shared

          def initialize(_options = {})
            require "ovirtsdk4"
          end

          def ovirt_attrs(obj)
            shared_ovirt_attrs(obj) do
              xml = read_xml("vnic_profile.xml")
              Nokogiri::XML(xml).xpath("/vnic_profile/network/@id").to_s
            end
          end

          private

          def client
            return @client if defined?(@client)
          end

          # read mocks xml
          def read_xml(file_name)
            file_path = File.join(__dir__, "../requests", "compute/v4", "mock_files", file_name)
            File.read(file_path)
          end
        end

        class Real
          include Shared

          def initialize(options = {})
            require "ovirtsdk4"
            username   = options[:ovirt_username]
            password   = options[:ovirt_password]
            server     = options[:ovirt_server]
            port       = options[:ovirt_port]       || 8080
            api_path   = options[:ovirt_api_path]   || "/api"
            url        = options[:ovirt_url]        || "https://#{server}:#{port}#{api_path}"

            connection_opts = {
              :url => url,
              :username => username,
              :password => password
            }
            @datacenter = options[:ovirt_datacenter]
            connection_opts[:ca_file]  = options[:ca_file]
            connection_opts[:ca_certs] = [OpenSSL::X509::Certificate.new(options[:public_key])] if options[:public_key].present?

            @client = ExceptionWrapper.new(OvirtSDK4::Connection.new(connection_opts))
          end

          def ovirt_attrs(obj)
            shared_ovirt_attrs(obj) do
              client.follow_link(obj.vnic_profile).network.id
            end
          end

          def api_version
            api = client.system_service.get
            api.product_info.version.full_version
          end

          def datacenter
            datacenter_hash[:id]
          end

          def datacenter_hash
            @datacenter_hash ||= datacenters.find { |x| x[:id] == @datacenter } || datacenters.find { |x| x[:name] == @datacenter } if @datacenter
            @datacenter_hash ||= datacenters.first
          end

          def blank_template
            @blank_template ||= client.system_service.get.special_objects.blank_template
          end

          def create_search_by_datacenter(search: nil, datacenter: nil, page: nil)
            unless datacenter raise ::Fog::Ovirt::Errors::OvirtEngineError('Cannot create search request by datacenter, when datacenter is nil')
            search ||= ""
            search += " datacenter=#{datacenter}" if datacenter
            search += " page #{page}" if page
            search
          end

          private

          attr_reader :client
        end
      end
    end
  end
end
