--!strict
-- A token bucket per caller (PRD §14: every remote checks its rate): `rate` requests a second on
-- average, with bursts of up to `burst`. Pure: the caller passes the time in seconds.

export type Bucket = { rate: number, burst: number, tokens: number, last: number }

local RateLimit = {}

function RateLimit.new(rate: number, burst: number): Bucket
	return { rate = rate, burst = burst, tokens = burst, last = -math.huge }
end

-- Spends one request; false when the caller is over the limit.
function RateLimit.take(bucket: Bucket, now: number): boolean
	bucket.tokens = math.min(bucket.burst, bucket.tokens + (now - bucket.last) * bucket.rate)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return table.freeze(RateLimit)
