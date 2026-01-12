import boto3
import os
from botocore.exceptions import ClientError

ec2 = boto3.client("ec2")
nfw = boto3.client("network-firewall")

TGW_RT_ID = os.environ["TGW_ROUTE_TABLE_ID"]
EGRESS_ATTACHMENT_ID = os.environ["EGRESS_ATTACHMENT_ID"]
FIREWALL_NAME = os.environ["FIREWALL_NAME"]


def lambda_handler(event, context):
    """
    Controls TGW default route fail-open / fail-close
    based on Network Firewall health.
    """
    if firewall_healthy():
        restore_egress()
    else:
        fail_close()


def firewall_healthy():
    """
    Returns True only if ALL firewall endpoints are healthy.
    Any AZ degradation triggers fail-close.
    """
    try:
        resp = nfw.describe_firewall(FirewallName=FIREWALL_NAME)
        sync_states = resp["FirewallStatus"]["SyncStates"]

        for az, state in sync_states.items():
            if state.get("HealthStatus") != "HEALTHY":
                print(f"Firewall unhealthy in AZ {az}")
                return False

        return True

    except ClientError as e:
        # Fail-closed if firewall status cannot be determined
        print(f"Firewall health check failed: {e}")
        return False


def fail_close():
    """
    Removes default route and replaces with blackhole.
    """
    print("Fail-close engaged — blocking internet egress")

    delete_default_route()

    try:
        ec2.create_transit_gateway_route(
            TransitGatewayRouteTableId=TGW_RT_ID,
            DestinationCidrBlock="0.0.0.0/0",
            Blackhole=True
        )
    except ClientError as e:
        if e.response["Error"]["Code"] != "TransitGatewayRouteAlreadyExists":
            raise


def restore_egress():
    """
    Restores default route to egress VPC attachment.
    """
    print("Firewall healthy — restoring egress routing")

    delete_default_route()

    try:
        ec2.create_transit_gateway_route(
            TransitGatewayRouteTableId=TGW_RT_ID,
            DestinationCidrBlock="0.0.0.0/0",
            TransitGatewayAttachmentId=EGRESS_ATTACHMENT_ID
        )
    except ClientError as e:
        if e.response["Error"]["Code"] != "TransitGatewayRouteAlreadyExists":
            raise


def delete_default_route():
    """
    Safely deletes the default TGW route if present.
    """
    try:
        ec2.delete_transit_gateway_route(
            TransitGatewayRouteTableId=TGW_RT_ID,
            DestinationCidrBlock="0.0.0.0/0"
        )
    except ClientError as e:
        if e.response["Error"]["Code"] != "InvalidRoute.NotFound":
            raise
