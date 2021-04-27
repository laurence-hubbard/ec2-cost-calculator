#! /bin/bash

echo "numberOfInstances,instanceType,costPerInstancePerHrUSD,costPerHrUSD,costPerDayUSD,costPerYrUSD"

# echo "rm -f /tmp/instances"
rm -f /tmp/instances

while read PROFILE; do

    # echo "aws --profile "$PROFILE" ec2 describe-instances | jq '.Reservations[].Instances[] | select(.State.Name=="running") | .InstanceType' -r >> /tmp/instances"
    aws --profile "$PROFILE" ec2 describe-instances | jq '.Reservations[].Instances[] | select(.State.Name=="running") | .InstanceType' -r >> /tmp/instances

done <<<"$(cat list-of-aws-profiles.txt)"

MAIN_PROFILE="$(head -1 list-of-aws-profiles.txt)"

# echo "cat /tmp/instances | sort | uniq -c > /tmp/instance-counts"
cat /tmp/instances | sort | uniq -c > /tmp/instance-counts

TOTAL_COST_PER_HOUR=0
TOTAL_COST_PER_DAY=0
TOTAL_COST_PER_YEAR=0

while read INSTANCE_COUNT; do

    COUNT=$(echo $INSTANCE_COUNT | awk '{print $1}')
    INSTANCE_TYPE=$(echo $INSTANCE_COUNT | awk '{print $2}')
    INSTANCE_COST=$(aws --profile "${MAIN_PROFILE}" pricing get-products --service-code AmazonEC2 --filters \
        "Type=TERM_MATCH,Field=usagetype,Value=EU-BoxUsage:${INSTANCE_TYPE}" \
        "Type=TERM_MATCH,Field=operatingSystem,Value=Linux" \
        "Type=TERM_MATCH,Field=instanceType,Value=${INSTANCE_TYPE}" \
        "Type=TERM_MATCH,Field=preInstalledSw,Value=NA" \
        "Type=TERM_MATCH,Field=location,Value=EU (Ireland)" \
        --region us-east-1 | jq -rc '.PriceList[0]' -c \
        | jq '.terms.OnDemand|to_entries[0]|.value.priceDimensions|to_entries[0]|.value.pricePerUnit.USD' -r)

    COST_PER_HOUR=$(echo ${COUNT}*${INSTANCE_COST} | bc -l)
    COST_PER_DAY=$(echo 24*${COST_PER_HOUR} | bc -l)
    COST_PER_YEAR=$(echo 365*${COST_PER_DAY} | bc -l)

    echo "${COUNT},${INSTANCE_TYPE},${INSTANCE_COST},${COST_PER_HOUR},${COST_PER_DAY},${COST_PER_YEAR}"

    TOTAL_COST_PER_HOUR=$(echo "${TOTAL_COST_PER_HOUR}+${COST_PER_HOUR}" | bc -l)
    TOTAL_COST_PER_DAY=$(echo "${TOTAL_COST_PER_DAY}+${COST_PER_DAY}" | bc -l)
    TOTAL_COST_PER_YEAR=$(echo "${TOTAL_COST_PER_YEAR}+${COST_PER_YEAR}" | bc -l)

done </tmp/instance-counts

echo ---------------------------
echo TOTAL_COST_PER_HOUR=${TOTAL_COST_PER_HOUR}

echo ---------------------------
echo TOTAL_COST_PER_DAY=${TOTAL_COST_PER_DAY}

echo ---------------------------
echo TOTAL_COST_PER_YEAR=${TOTAL_COST_PER_YEAR}


# For reference:
# https://stackoverflow.com/questions/7334035/get-ec2-pricing-programmatically

# aws pricing get-products --service-code AmazonEC2 --filters "Type=TERM_MATCH,Field=instanceType,Value=c4.large"  --region us-east-1 | jq '.PriceList[]' -r | jq '.product.attributes.location' -r | sort | uniq
# AWS GovCloud (US-West)
# Asia Pacific (Mumbai)
# Asia Pacific (Osaka-Local)
# Asia Pacific (Seoul)
# Asia Pacific (Singapore)
# Asia Pacific (Sydney)
# Asia Pacific (Tokyo)
# Canada (Central)
# China (Beijing)
# China (Ningxia)
# EU (Frankfurt)
# EU (Ireland)
# EU (London)
# EU (Paris)
# South America (Sao Paulo)
# US East (N. Virginia)
# US East (Ohio)
# US West (N. California)
# US West (Oregon)
