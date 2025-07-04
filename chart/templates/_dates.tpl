{{- /*
isLeapYear - Determines if a given year is a leap year
Usage: isLeapYear $year
*/}}
{{- define "dates.isLeapYear" -}}
{{- $year := . -}}
{{- if mod $year 400 | eq 0 -}}
    {{- true -}}
{{- else if mod $year 100 | eq 0 -}}
    {{- false -}}
{{- else if mod $year 4 | eq 0 -}}
    {{- true -}}
{{- else -}}
    {{- false -}}
{{- end -}}
{{- end -}}

{{- /*
daysInMonth - Returns the number of days in a given month of a given year
Usage: daysInMonth $year $month
*/}}
{{- define "dates.daysInMonth" -}}
{{- $year := index . 0 -}}
{{- $month := index . 1 -}}
{{- if or (eq $month 4) (eq $month 6) (eq $month 9) (eq $month 11) -}}
    {{- 30 -}}
{{- else if eq $month 2 -}}
    {{- if include "dates.isLeapYear" $year | trim | eq "true" -}}
        {{- 29 -}}
    {{- else -}}
        {{- 28 -}}
    {{- end -}}
{{- else -}}
    {{- 31 -}}
{{- end -}}
{{- end -}}

{{- /*
decreaseYear - Decreases the year by 1
Usage: decreaseYear $year
*/}}
{{- define "dates.decreaseYear" -}}
{{- $year := . -}}
{{- sub $year 1 -}}
{{- end -}}

{{- /*
decreaseMonth - Decreases the month by 1, rolls over to previous year if needed
Usage: decreaseMonth $year $month
Returns: [year, month]
*/}}
{{- define "dates.decreaseMonth" -}}
{{- $year := index . 0 -}}
{{- $month := index . 1 -}}
{{- if eq $month 1 -}}
    {{- $year = include "dates.decreaseYear" $year | atoi -}}
    {{- $month = 12 -}}
{{- else -}}
    {{- $month = sub $month 1 -}}
{{- end -}}
{{- printf "%d %d" $year $month -}}
{{- end -}}

{{- /*
decreaseDay - Decreases the day by the given range, rolls over to previous month/year if needed
Usage: decreaseDay $year $month $day
Returns: [year, month, day]
*/}}
{{- define "dates.decreaseDay" -}}
{{- $year := index . 0 -}}
{{- $month := index . 1 -}}
{{- $day := index . 2 -}}
{{- if eq $day 1 -}}
    {{- $yearMonth := list $year $month | include "dates.decreaseMonth" -}}
    {{- $parts := $yearMonth | splitList " " -}}
    {{- $year = index $parts 0 | atoi -}}
    {{- $month = index $parts 1 | atoi -}}
    {{- $day = list $year $month | include "dates.daysInMonth" | atoi -}}
{{- else -}}
    {{- $day = sub $day 1 -}}
{{- end -}}
{{- printf "%d %d %d" $year $month $day -}}
{{- end -}}

{{- /*
formatDate - Formats a date as YYYY-MM-DD
Usage: formatDate $year $month $day
*/}}
{{- define "dates.formatDate" -}}
{{- $year := index . 0 -}}
{{- $month := index . 1 -}}
{{- $day := index . 2 -}}
{{- printf "%04d-%02d-%02d" $year $month $day -}}
{{- end -}}

{{- /*
dateRange - Creates a date range string in format datePast/dateNow based on range type
Usage: dateRange $rangeType $currentYear $currentMonth $currentDay
Range types: "day", "month", "year"
*/}}
{{- define "dates.dateRange" -}}
{{- $rangeType := index . 0 -}}
{{- $currentYear := index . 1 | int -}}
{{- $currentMonth := index . 2 | int -}}
{{- $currentDay := index . 3 | int -}}

{{- $pastYear := $currentYear -}}
{{- $pastMonth := $currentMonth -}}
{{- $pastDay := $currentDay -}}

{{- if eq $rangeType "day" -}}
    {{- $pastDate := list $pastYear $pastMonth $pastDay | include "dates.decreaseDay" -}}
    {{- $pastParts := $pastDate | splitList " " -}}
    {{- $pastYear = index $pastParts 0 | atoi -}}
    {{- $pastMonth = index $pastParts 1 | atoi -}}
    {{- $pastDay = index $pastParts 2 | atoi -}}
{{- else if eq $rangeType "month" -}}
    {{- $pastYearMonth := list $pastYear $pastMonth | include "dates.decreaseMonth" -}}
    {{- $pastParts := $pastYearMonth | splitList " " -}}
    {{- $pastYear = index $pastParts 0 | atoi -}}
    {{- $pastMonth = index $pastParts 1 | atoi -}}
    
    {{- /* Handle case where the day doesn't exist in the past month */}}
    {{- $daysInPastMonth := list $pastYear $pastMonth | include "dates.daysInMonth" | atoi -}}
    {{- if gt $pastDay $daysInPastMonth -}}
        {{- $pastDay = $daysInPastMonth -}}
    {{- end -}}
{{- else if eq $rangeType "year" -}}
    {{- $pastYear = include "dates.decreaseYear" $pastYear | atoi -}}
    
    {{- /* Handle February 29 for leap years */}}
    {{- if and (eq $pastMonth 2) (eq $pastDay 29) -}}
        {{- if include "dates.isLeapYear" $pastYear | trim | ne "true" -}}
            {{- $pastDay = 28 -}}
        {{- end -}}
    {{- end -}}
{{- end -}}

{{- $pastDate := list $pastYear $pastMonth $pastDay | include "dates.formatDate" -}}
{{- $currentDate := list $currentYear $currentMonth $currentDay | include "dates.formatDate" -}}
{{- printf "%s/%s" $pastDate $currentDate -}}
{{- end -}}